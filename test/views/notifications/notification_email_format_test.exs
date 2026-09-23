defmodule Bonfire.UI.Social.NotificationEmailFormatTest do
  @moduledoc """
  `?_email_format=mjml` shows a page as email: every component that has an email template renders that instead of its HTML, so the notifications feed, with its chips and filters, can be browsed as the emails it would send.

  MJML's output carries its own `mj-column` classes, which no page markup has, so they are what tells an email rendering apart from the normal one.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "a post of mine that gets liked"}},
        boundary: "public"
      )

    {:ok, _} = Bonfire.Social.Likes.like(fake_user!(), post)

    {:ok, conn: conn(user: me, account: account)}
  end

  defp rendered(conn, path) do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    render(view)
  end

  test "without it, the notifications feed is HTML", %{conn: conn} do
    html = rendered(conn, "/notifications")

    # the positive first: the like is in the feed
    assert html =~ "a post of mine that gets liked"
    refute html =~ "mj-column"
  end

  test "with it, the notifications feed's rows are their emails", %{conn: conn} do
    html = rendered(conn, "/notifications?_email_format=mjml")

    assert html =~ "mj-column"
    assert html =~ "a post of mine that gets liked"
  end

  test "it stays on while browsing between chips, and goes off when asked", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/notifications?_email_format=mjml")
    render_async(view)

    # a chip's link carries no `_email_format`, which is what used to switch it back to HTML
    render_patch(view, "/notifications/reactions")
    render_async(view)
    assert render(view) =~ "mj-column"

    render_patch(view, "/notifications?_email_format=html")
    render_async(view)
    refute render(view) =~ "mj-column"
  end
end
