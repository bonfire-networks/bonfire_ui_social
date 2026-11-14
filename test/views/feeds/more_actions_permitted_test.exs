defmodule Bonfire.UI.Social.MoreActionsPermitted.Test do
  @moduledoc """
  The "More actions" menu's rows that depend on what the viewer may do with a post (boundary details, edit, delete…) are decided when the menu is opened, from the post's boundary when a feed or the post's page loaded it (`Bonfire.Boundaries.LiveHandler.preload_boundaries/2`), so they aren't rendered for every post up front. These open it on the post's own page, where the main object is outside any stream so the rows reach the test DOM. The edit and delete flows are in `post_edit_test.exs` and `post_delete_test.exs`.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  use Bonfire.Common.E

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  defp publish!(user, body) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}},
        boundary: "public"
      )

    post
  end

  describe "before the menu is opened" do
    test "the permission rows wait for the menu, even with the post's boundary loaded", %{
      conn: conn,
      me: me
    } do
      post = publish!(me, "loaded")

      conn
      |> visit("/post/#{id(post)}")
      |> assert_has("[data-id=permitted_actions_placeholder]")
      |> refute_has("[data-role=edit_post]")
    end

    # where nothing loaded the boundary, which a page no longer reaches, so rendered directly
    test "without a loaded boundary, the rows are placeholders until it is opened", %{me: me} do
      post = publish!(me, "not loaded")

      html =
        render_component(Bonfire.UI.Social.Activity.PermittedActionsLive, %{
          id: "permitted_actions_not_loaded",
          object: post,
          creator: me,
          object_boundary: nil,
          __context__: %{current_user: me}
        })

      assert html =~ ~s(data-id="permitted_actions_placeholder")
      refute html =~ ~s(data-role="edit_post")
    end

    test "given a loaded boundary, the rows still wait for the menu to open", %{me: me} do
      post = publish!(me, "given loaded")
      loaded = Bonfire.Boundaries.boundaries_on_objects([id(post)], me) |> Map.get(id(post))

      html =
        render_component(Bonfire.UI.Social.Activity.PermittedActionsLive, %{
          id: "permitted_actions_loaded",
          object: post,
          creator: me,
          object_boundary: loaded,
          __context__: %{current_user: me}
        })

      assert html =~ ~s(data-id="permitted_actions_placeholder")
      refute html =~ ~s(data-role="edit_post")
    end

    test "a guest gets neither the rows nor their placeholder", %{me: me} do
      post = publish!(me, "lazy for guests")

      Phoenix.ConnTest.build_conn()
      |> visit("/post/#{id(post)}?cache=skip")
      |> assert_has("article", text: "lazy for guests")
      |> refute_has("[data-id=permitted_actions]")
    end
  end

  describe "opening the menu" do
    test "shows the author the boundary, edit and delete", %{conn: conn, me: me} do
      post = publish!(me, "mine")

      conn
      |> visit("/post/#{id(post)}")
      |> open_more_menu()
      |> refute_has("[data-id=permitted_actions_placeholder]")
      |> assert_has("[data-id=boundary_details]")
      |> assert_has("[data-role=edit_post]")
      |> assert_has("[data-role=delete_object] [role=delete]")
    end

    test "shows someone else the boundary but not edit or delete", %{conn: conn} do
      post = publish!(fake_user!(fake_account!()), "theirs")

      conn
      |> visit("/post/#{id(post)}")
      |> open_more_menu()
      # the control: the rows loaded, so the absences below are the permission
      |> assert_has("[data-id=boundary_details]")
      |> refute_has("[data-role=edit_post]")
      |> refute_has("[data-role=delete_object]")
    end

    test "the boundary details open in a modal", %{conn: conn, me: me} do
      post = publish!(me, "boundary details")

      conn
      |> visit("/post/#{id(post)}")
      |> open_more_menu()
      |> click_button("[data-id=boundary_details] [data-role=open_modal]", "Boundary details")
      |> assert_has("[data-role=action_toggle_reply]")
    end
  end

  describe "the rows" do
    test "\"Remove from feeds\" is labelled as such and sends the feeds event with the activity",
         %{conn: conn, me: me} do
      post = publish!(me, "post to take out of feeds")
      activity_id = id(e(post, :activity, nil))
      assert activity_id

      conn
      |> visit("/post/#{id(post)}")
      |> open_more_menu()
      |> click_button("[data-role=delete_activity] [data-role=open_modal]", "Remove from feeds")
      |> assert_has(
        "[phx-click='Bonfire.Social.Feeds:delete'][phx-value-id='#{activity_id}']",
        text: "Remove from feeds"
      )
    end
  end

  describe "the rest of the menu" do
    test "non-boundary actions are there before the menu is opened", %{conn: conn, me: me} do
      publish!(me, "feed post for copy link")

      conn
      |> visit("/feed/local")
      |> assert_has("[data-role=label]", text: "Copy link")
    end

    test "Copy link button wires up the clipboard hook with the post's ActivityPub id", %{
      conn: conn,
      me: me
    } do
      post = publish!(me, "feed post for copy link wiring")

      # a local post's id here, which opens its page in a browser
      permalink = Bonfire.Common.URIs.base_url() <> "/pub/objects/#{post.id}"

      conn
      |> visit("/feed/local")
      # A link that also carries the URL in data-clipboard-text: the Copy hook copies it and stops the navigation, and without the hook it still opens the link. Without the hook or the data, a click just navigated away and copied nothing (issue #1951).      
      |> assert_has(
        ~s(a[phx-hook="Copy"][data-clipboard-text="#{permalink}"]),
        text: "Copy link"
      )
    end

    test "Copy link on a remote post copies its address on the server it came from", %{
      conn: conn
    } do
      {post, _} = Bonfire.Social.Fake.create_test_content(:remote, nil, nil)
      # the positive first: the post has a remote address to copy
      assert "https://example.local/post/1" =
               Bonfire.Common.URIs.canonical_url(post, preload_if_needed: true)

      conn
      |> visit("/feed/remote")
      |> assert_has(
        ~s(a[phx-hook="Copy"][data-clipboard-text="https://example.local/post/1"]),
        text: "Copy link"
      )
    end

    test "Copy link button keeps the explicit permalink in the inline actions render" do
      Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

      permalink = "https://example.test/discussion/previewed-post"

      html =
        render_component(Bonfire.UI.Social.Activity.ActionsLive, %{
          id: "preview-actions",
          activity: %{id: "preview-activity"},
          creator: nil,
          subject_user: nil,
          object: %{},
          object_type: Bonfire.Data.Social.Post,
          object_type_readable: "post",
          verb: "Create",
          thread_id: "preview-thread",
          permalink: permalink,
          showing_within: :thread,
          reply_count: nil,
          activity_component_id: nil,
          thread_title: nil,
          feed_name: nil,
          feed_id: nil,
          hide_reply: false,
          viewing_main_object: false,
          flagged: nil,
          thread_mode: nil,
          object_boundary: :skip_boundary_preload,
          is_remote: false,
          hide_more_actions: false,
          parent_id: nil,
          published_in: nil,
          labelled: nil,
          hide_actions: false,
          is_answer: false,
          can_pin_in_thread: false,
          participants: nil,
          quotes: [],
          my_boost: nil,
          my_like: nil,
          my_bookmark: nil,
          boost_count: nil,
          like_count: nil,
          show_counts: nil,
          __context__: %{}
        })

      assert html =~ ~s(phx-hook="Copy")
      assert html =~ ~s(data-clipboard-text="#{permalink}")
    end
  end
end
