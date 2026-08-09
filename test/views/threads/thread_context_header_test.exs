defmodule Bonfire.UI.Social.Threads.ContextHeaderTest do
  @moduledoc """
  The morphing context header on thread pages: a server-rendered compact author bar
  (hidden until the ThreadContextHeader JS hook reveals it when the main post scrolls
  out of view — the scroll behaviour itself can't run in these tests, so we assert the
  markup contract the hook relies on).
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    alice = fake_user!(account)

    {:ok, op} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{
          post_content: %{html_body: "<p>A post worth scrolling back to</p>"}
        },
        boundary: "public"
      )

    {:ok, conn: conn(user: alice, account: account), alice: alice, op: op}
  end

  test "the thread page renders the context header bar (hidden) with the author's name", %{
    conn: conn,
    alice: alice,
    op: op
  } do
    name = e(alice, :profile, :name, nil) || e(alice, :character, :username, nil)

    conn
    |> visit("/post/#{id(op)}")
    # the hook's target anchor
    |> assert_has("#thread_main_object")
    # zero-height sticky wrapper + hidden bar the hook reveals (the "_page" suffix
    # distinguishes it from a preview-modal instance of the same thread)
    |> assert_has(
      "#thread_context_header_#{id(op)}_page [data-role='thread-context-bar'][aria-hidden='true']"
    )
    |> assert_has("[data-role='thread-context-bar']", text: name)
  end
end
