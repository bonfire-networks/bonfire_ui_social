defmodule Bonfire.Social.Threads.ThreadsTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other_account = fake_account!()
    other_user = fake_user!(other_account)

    # Create a post
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Original post"}},
        boundary: "public"
      )

    conn = conn(user: me, account: account)

    {:ok, conn: conn, me: me, other_user: other_user, post: post, other_account: other_account}
  end

  # test "when opening a post from another user profile, the main post subject is shown", %{
  #   other_user: other_user,
  #   me: me,
  #   other_account: other_account,
  #   post: post
  # } do
  #   conn = conn(user: other_user, account: other_account)
  #   conn
  #   |> visit("/@#{me.character.username}")
  #   |> unwrap(fn view ->
  #     view |> element("a", "activity timestamp")
  #     |> render_click()
  #   end)
  #   |> PhoenixTest.open_browser()
  # end

  test "replies to the original post appear instantly", %{
    conn: conn,
    post: post,
    other_user: other_user
  } do
    post_view =
      conn
      |> visit("/post/#{post.id}")

    attrs_reply = %{
      post_content: %{html_body: "First reply"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    post_view
    # |> PhoenixTest.open_browser()
    |> assert_has("article", text: "First reply")
  end

  test "replies to comments appear instantly", %{conn: conn, post: post, other_user: other_user} do
    post_view =
      conn
      |> visit("/post/#{post.id}")

    attrs_reply = %{
      post_content: %{html_body: "First reply"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    attrs_reply2 = %{
      post_content: %{html_body: "Second reply"},
      reply_to_id: post.id
    }

    {:ok, reply2} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply2, boundary: "public")

    post_view
    |> assert_has("article", text: "Second reply")
  end

  test "activities within thread comments have proper preloads in default mode", %{
    conn: conn,
    post: post,
    other_user: other_user
  } do
    # Create a reply with content
    attrs_reply = %{
      post_content: %{html_body: "Reply with preloadable data"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    # Visit the thread and verify preloads
    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-id='comment']")
    # Verify creator/subject is preloaded
    |> assert_has("[data-role=subject]")
    |> assert_has("[data-id=subject_name]", text: other_user.profile.name)
    |> assert_has("[data-id=subject_avatar]")
    # Verify post content is preloaded
    |> assert_has("[data-id=activity_note]", text: "Reply with preloadable data")

    # Verify the link to creator profile works
    # |> assert_has("[data-id=subject_avatar][href='/@#{other_user.character.username}']")
  end

  test "activities within thread comments have proper preloads in flat mode", %{
    conn: conn,
    post: post,
    other_user: other_user
  } do
    # Set flat mode
    Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

    # Create a reply with content
    attrs_reply = %{
      post_content: %{html_body: "Reply in flat mode"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    # Visit the thread and verify preloads
    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[data-role='comment-flat']")
    # Verify creator/subject is preloaded
    |> assert_has("[data-role=subject]")
    |> assert_has("[data-id=subject_name]", text: other_user.profile.name)
    |> assert_has("[data-id=subject_avatar]")
    # Verify post content is preloaded
    |> assert_has("[data-id=activity_note]", text: "Reply in flat mode")
    |> PhoenixTest.open_browser()

    # Verify the link to creator profile works
    # |> assert_has("[data-id=subject_avatar][href='/@#{other_user.character.username}']")
  end

  test "switching to flat mode via UI maintains proper preloads", %{
    conn: conn,
    post: post,
    other_user: other_user
  } do
    # Create a reply with content
    attrs_reply = %{
      post_content: %{html_body: "Reply to test mode switching"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    # Visit the thread (defaults to nested/threaded mode)
    conn
    |> visit("/discussion/#{post.id}")
    # Verify we start in threaded mode
    |> assert_has("[data-id='comment']")
    |> click_link("li[phx-value-thread_mode='flat']", "Flat list")
    # |> click_button("Flat list")  # or find the actual button/link text
    # Click the flat mode option in the dropdown
    # |> unwrap(fn view ->
    #   view
    #   |> element("li[phx-value-thread_mode='flat']")
    #   |> render_click()
    # end)
    # Verify we switched to flat mode
    |> assert_has("[data-role='comment-flat']")
    # Verify creator/subject is still preloaded after switching
    |> assert_has("[data-role=subject]")
    |> assert_has("[data-id=subject_name]", text: other_user.profile.name)
    |> assert_has("[data-id=subject_avatar]")
    # Verify post content is still accessible
    |> assert_has("[data-id=activity_note]", text: "Reply to test mode switching")
  end

  test "LiveHandler.reply/3 only includes participants from reply_to rather than the whole thread",
       %{
         me: me,
         other_user: other_user,
         post: post
       } do
    # Publish a reply with a tag/mention
    third_user = fake_user!()
    reply_user = fake_user!()
    tag_user = other_user

    attrs_reply = %{
      post_content: %{html_body: "Reply with mention"},
      reply_to_id: post.id,
      tags: [tag_user.character.id]
    }

    {:ok, reply} =
      Posts.publish(current_user: reply_user, post_attrs: attrs_reply, boundary: "public")

    # create an unrelated reply in the thread to ensure its participants are not included
    attrs_reply = %{
      post_content: %{html_body: "Another reply without mention"},
      reply_to_id: post.id
    }

    {:ok, reply2} =
      Posts.publish(current_user: third_user, post_attrs: attrs_reply, boundary: "public")

    # Simulate a minimal socket
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        current_user: me,
        activity: reply.activity,
        object: reply,
        published_in: nil,
        object_boundary: nil,
        object_type: nil
      }
    }

    # Call prepare_reply_assigns/4 directly
    assigns =
      Bonfire.Social.Threads.LiveHandler.prepare_reply_assigns(
        reply,
        reply.activity,
        nil,
        socket
      )

    # Build expected participants manually from tags
    expected_participants = [
      reply_user.id,
      tag_user.id
    ]

    # Extract actual participants from assigns (simulate what reply/3 would use)
    actual_participants =
      assigns
      |> debug("assigns result")
      |> Keyword.get(:participants, [])
      |> Enums.ids()

    # Assert only the tagged user is included
    assert actual_participants == expected_participants
  end
end
