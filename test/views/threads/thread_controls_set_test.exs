defmodule Bonfire.UI.Social.ThreadControlsSetTest do
  @moduledoc "The thread's own view controls (layout and sort order) change how the thread is shown, through the `set` event."
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  import Phoenix.LiveViewTest,
    only: [
      live: 2,
      element: 2,
      render_click: 1,
      has_element?: 2,
      with_target: 2,
      render_hook: 2,
      render_hook: 3,
      render_async: 1
    ]

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other = fake_user!(fake_account!())

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Original post"}},
        boundary: "public"
      )

    {:ok, _reply} =
      Posts.publish(
        current_user: other,
        post_attrs: %{post_content: %{html_body: "A reply"}, reply_to_id: post.id},
        boundary: "public"
      )

    %{conn: conn(user: me, account: account), post: post}
  end

  test "choosing a sort order switches the thread view", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, "/discussion/#{post.id}")

    most_replies = "#thread-sort-#{post.id}-reply_count-desc"

    assert has_element?(view, most_replies), "control: the sort option is on the page"
    refute has_element?(view, most_replies <> "[checked]")

    view |> element(most_replies) |> render_click()

    assert has_element?(view, most_replies <> "[checked]")
  end

  test "an empty `set` push (pull-to-refresh) refreshes the thread", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, "/discussion/#{post.id}")
    render_async(view)

    thread = "#thread_#{post.id}"
    assert has_element?(view, thread), "control: the thread component is on the page"

    view |> with_target(thread) |> render_hook("set", %{})

    assert render_async(view) =~ "A reply"
    assert has_element?(view, thread)
  end

  test "a guest can pull-to-refresh a public thread", %{post: post} do
    {:ok, view, _html} = live(conn(), "/discussion/#{post.id}")
    assert render_async(view) =~ "A reply", "control: the guest sees the replies"

    thread = "#thread_#{post.id}"
    assert has_element?(view, thread), "control: the thread component is on the page"

    view |> with_target(thread) |> render_hook("set", %{})

    assert render_async(view) =~ "A reply"
    assert has_element?(view, thread)
  end
end
