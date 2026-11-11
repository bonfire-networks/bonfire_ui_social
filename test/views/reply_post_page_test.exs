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

  describe "a reply link naming a reply that is not this thread's, or not visible to the viewer" do
    setup %{post: post} do
      alice = fake_user!()
      bob = fake_user!()

      publish = fn user, reply_to_id, body, boundary ->
        {:ok, reply} =
          Posts.publish(
            current_user: user,
            post_attrs: %{post_content: %{html_body: body}, reply_to_id: reply_to_id},
            boundary: boundary
          )

        reply
      end

      # a deep visible reply of this thread, and a deep reply nobody but its author can see
      deep =
        Enum.scan(1..5, post, fn n, parent ->
          publish.(alice, parent.id, "visible deep reply #{n}", "public")
        end)
        |> List.last()

      hidden = publish.(alice, deep.id, "secret deep reply", "mentions")

      {:ok, other_op} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "other thread post"}},
          boundary: "public"
        )

      other =
        Enum.scan(1..5, other_op, fn n, parent ->
          publish.(alice, parent.id, "other thread reply #{n}", "public")
        end)
        |> List.last()

      {:ok,
       bob_conn: conn(user: bob, account: bob.account),
       guest_conn: conn(),
       deep: deep,
       hidden: hidden,
       other: other}
    end

    defp main_text(conn, path) do
      {:ok, view, _html} =
        case live(conn, path) do
          {:error, {_redirect, %{to: to}}} -> live(conn, to)
          loaded -> loaded
        end

      view
      |> render_async()
      |> Floki.parse_document!()
      |> Floki.find("[data-id=main_section]")
      |> Floki.text()
    end

    for conn_name <- [:bob_conn, :guest_conn] do
      test "shows the visible deep reply, but not the hidden one or another thread's (#{conn_name})",
           ctx do
        conn = ctx[unquote(conn_name)]
        post = ctx.post

        assert main_text(conn, "/discussion/#{post.id}/reply/6/#{ctx.deep.id}") =~
                 "visible deep reply 5"

        hidden_text = main_text(conn, "/discussion/#{post.id}/reply/7/#{ctx.hidden.id}")
        refute hidden_text =~ "secret deep reply"

        other_text = main_text(conn, "/discussion/#{post.id}/reply/6/#{ctx.other.id}")
        refute other_text =~ "other thread reply"
      end
    end
  end

  test "the start of a thread keeps its own page", %{conn: conn, post: post} do
    assert {:ok, view, _html} = live(conn, "/post/#{post.id}")
    # as text, since the HTML escapes the apostrophe
    assert view |> render_async() |> Floki.parse_document!() |> Floki.text() =~
             "alice's original post"
  end
end
