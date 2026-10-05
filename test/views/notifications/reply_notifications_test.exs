defmodule Bonfire.Social.Notifications.Threads.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes

  setup do
    alice = fake_user!("alice")
    bob = fake_user!("bob")
    carl = fake_user!("carl")

    conn_alice = conn(user: alice)
    conn_bob = conn(user: bob)
    conn_carl = conn(user: carl)

    {:ok,
     %{
       alice: alice,
       bob: bob,
       carl: carl,
       conn_alice: conn_alice,
       conn_bob: conn_bob
       # conn_carl: conn_carl
     }}
  end

  describe "DO NOT show" do
    test "replies I'm NOT allowed to see in my notifications", %{
      bob: bob,
      carl: carl,
      conn_bob: conn_bob
    } do
      # Bob creates a public post so Carl can see and reply to it
      attrs = %{post_content: %{html_body: "here is an epic html post"}}
      assert {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # Carl replies to Bob's post with a private reply (Bob shouldn't see it)
      attrs_reply = %{
        post_content: %{summary: "summary", html_body: "epic html reply"},
        reply_to_id: post.id
      }

      # Private reply - Bob shouldn't be able to see this: readable by the people it mentions, and it mentions nobody. (Published with no boundary, a reply is readable by the author it answers, so that isn't a private one)
      assert {:ok, post_reply} =
               Posts.publish(current_user: carl, post_attrs: attrs_reply, boundary: "mentions")

      # the premise, checked rather than assumed
      refute Bonfire.Boundaries.can?(bob, :read, post_reply)

      # Bob checks notifications - should NOT see Carl's private reply
      conn_bob
      |> visit("/notifications")
      |> refute_has("article", text: "epic html reply")
    end
  end

  # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context

  test "As a user, when someone replies to my activity, I want to see it in notifications, included the author's name, and the content of the original activity",
       %{alice: alice, bob: bob, conn_alice: conn_alice} do
    # Alice creates a post
    attrs = %{
      post_content: %{summary: "summary", html_body: "alice's first post"}
    }

    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Bob replies to Alice's post, incl @ mention
    attrs_reply = %{
      post_content: %{
        summary: "summary",
        html_body: "@alice bob's reply to the post"
      },
      reply_to_id: post.id
    }

    {:ok, _post_reply} =
      Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    # Alice checks her notifications
    conn_alice
    |> visit("/notifications")
    |> assert_has("article", text: attrs_reply.post_content.html_body)
    |> assert_has("[data-role=subject]", text: bob.profile.name)
    |> assert_has("[data-verb=reply]")

    # |> assert_has("article", text: attrs.post_content.html_body)
  end

  # what the preview hook does on a click: push `open` to the row's `OpenPreviewLive`, which renders the thread in the preview without a page load
  test "opening a reply's notification previews the thread from its original post, with the reply once",
       %{alice: alice, bob: bob, conn_alice: conn_alice} do
    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "alice's original post"}},
        boundary: "public"
      )

    {:ok, reply} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{
          post_content: %{html_body: "@alice bob's answer to it"},
          reply_to_id: post.id
        },
        boundary: "public"
      )

    {:ok, view, _html} = live(conn_alice, "/notifications")

    # the positive first: the reply's notification is there to click
    row = "article[data-object_id='#{reply.id}']"
    assert has_element?(view, row)

    view
    |> with_target("#{row} [id*='_open_preview_']")
    |> render_hook("open", %{})

    preview = view |> element("#preview_content") |> render() |> Floki.parse_fragment!()
    text = Floki.text(preview)

    assert text =~ "alice's original post", "the thread starts from the post that was answered"

    assert length(String.split(text, "bob's answer to it")) == 2,
           "the reply shows once, not also as the thread's start"
  end

  # the same, for a reply that arrives while the notifications page is open: its row comes from the live push, not from the feed query
  test "opening a reply's notification that arrived live previews the thread from its original post, with the reply once",
       %{alice: alice, bob: bob, conn_alice: conn_alice} do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "alice's original post"}},
        boundary: "public"
      )

    {:ok, view, _html} = live(conn_alice, "/notifications")

    {:ok, reply} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{
          post_content: %{html_body: "@alice bob's live answer"},
          reply_to_id: post.id
        },
        boundary: "public"
      )

    # the positive first: the reply's row arrived without a reload
    row = "article[data-object_id='#{reply.id}']"
    render(view)
    assert has_element?(view, row)

    view
    |> with_target("#{row} [id*='_open_preview_']")
    |> render_hook("open", %{})

    text =
      view |> element("#preview_content") |> render() |> Floki.parse_fragment!() |> Floki.text()

    assert text =~ "alice's original post", "the thread starts from the post that was answered"

    assert length(String.split(text, "bob's live answer")) == 2,
           "the reply shows once, not also as the thread's start"
  end

  # a tapped push notification makes the open tab navigate over its socket (`NAVIGATE` in bonfire_live.js), which mounts the post page without the server-rendered pass a reload has
  # parked: `live_redirect/2` to a post page answers `{:error, {:redirect, %{to: nil}}}` here, from /notifications and from another post page alike, so this can't drive live navigation yet
  @tag skip: "live_redirect to /post/:id redirects to nil in tests"
  test "a reply further down a thread, opened by live navigation, shows as a full load does",
       %{alice: alice, bob: bob, carl: carl, conn_alice: conn_alice} do
    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "alice's original post"}},
        boundary: "public"
      )

    {:ok, carls} =
      Posts.publish(
        current_user: carl,
        post_attrs: %{post_content: %{html_body: "carl's reply"}, reply_to_id: post.id},
        boundary: "public"
      )

    {:ok, bobs} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "bob's reply to carl"}, reply_to_id: carls.id},
        boundary: "public"
      )

    path = "/post/#{bobs.id}"

    # the reference: what a reload shows
    {:ok, _view, loaded_html} = live(conn_alice, path)

    loaded =
      loaded_html
      |> Floki.parse_document!()
      |> Floki.find("[data-id=main_section]")
      |> Floki.text()

    # from a page in the post page's own live session, since from another session the browser loads the page in full (`live_redirect` from /notifications answers with a redirect)
    {:ok, view, _html} = live(conn_alice, "/post/#{post.id}")
    {:ok, view, _html} = live_redirect(view, to: path)

    navigated =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("[data-id=main_section]")
      |> Floki.text()

    # how often each post's text appears, navigated to vs loaded, so a difference names which post is doubled or missing
    counts = fn text ->
      for t <- ["alice's original post", "carl's reply", "bob's reply to carl"],
          do: {t, length(String.split(text, t)) - 1}
    end

    assert counts.(navigated) == counts.(loaded)
  end
end
