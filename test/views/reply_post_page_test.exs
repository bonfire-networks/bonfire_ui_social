defmodule Bonfire.UI.Social.ReplyPostPageTest do
  @moduledoc """
  A reply's own page (`/post/<reply id>`), which old links, other servers and Mastodon clients still lead to, shows the same as its place in the thread (`/discussion/<thread id>/reply/<level>/<reply id>`), which is how the app links it.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    alice = fake_user!()
    carl = fake_user!()
    bob = fake_user!()

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

    {:ok, conn: conn(user: alice, account: alice.account), post: post, bobs: bobs}
  end

  # how often each post's text appears in the page's main section, once its async parts have loaded
  defp counts(conn, path) do
    {:ok, view, _html} =
      case live(conn, path) do
        {:error, {_redirect, %{to: to}}} -> live(conn, to)
        loaded -> loaded
      end

    text =
      view
      |> render_async()
      |> Floki.parse_document!()
      |> Floki.find("[data-id=main_section]")
      |> Floki.text()

    for t <- ["alice's original post", "carl's reply", "bob's reply to carl"],
        do: {t, length(String.split(text, t)) - 1}
  end

  test "a reply's own page shows what its place in the thread does", %{
    conn: conn,
    post: post,
    bobs: bobs
  } do
    in_thread = counts(conn, "/discussion/#{post.id}/reply/2/#{bobs.id}")

    # the positive first: the thread link's page has the reply
    assert {"bob's reply to carl", n} = List.keyfind(in_thread, "bob's reply to carl", 0)
    assert n > 0

    assert counts(conn, "/post/#{bobs.id}") == in_thread
  end

  test "a reply's own page opens at its place in the thread", %{
    conn: conn,
    post: post,
    bobs: bobs
  } do
    in_thread = "/discussion/#{post.id}/reply/2/#{bobs.id}"

    assert {:error, {kind, %{to: ^in_thread}}} = live(conn, "/post/#{bobs.id}")
    assert kind in [:redirect, :live_redirect]
  end

  test "a reply's discussion page opens at its place in the thread", %{
    conn: conn,
    post: post,
    bobs: bobs
  } do
    in_thread = "/discussion/#{post.id}/reply/2/#{bobs.id}"

    assert {:error, {kind, %{to: ^in_thread}}} = live(conn, "/discussion/#{bobs.id}")
    assert kind in [:redirect, :live_redirect]

    # and that page itself stays put, rather than redirecting again
    assert {:ok, _view, _html} = live(conn, in_thread)
  end

  test "the start of a thread keeps its own page", %{conn: conn, post: post} do
    assert {:ok, view, _html} = live(conn, "/post/#{post.id}")
    # as text, since the HTML escapes the apostrophe
    assert view |> render_async() |> Floki.parse_document!() |> Floki.text() =~
             "alice's original post"
  end
end
