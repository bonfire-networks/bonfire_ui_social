defmodule Bonfire.UI.Social.NotificationEmailFormatTest do
  @moduledoc """
  `?_email_format=mjml` shows a page as email: every component that has an email template renders that instead of its HTML, so the notifications feed, with its chips and filters, can be browsed as the emails it would send.

  An email renders the activity's line with its date ("liked your activity · Sep 24, 2026", worded as the notifications row words it), where the page shows a relative time, so that is what tells an email rendering apart from the normal one.
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

  # the like was made just now
  defp as_email,
    do: "liked your activity · " <> Bonfire.Common.DatesTimes.format_date(Date.utc_today())

  defp rendered(conn, path) do
    {:ok, view, _html} = live(conn, path)
    render_async(view)
    render(view)
  end

  # what a reader sees, since the email's line styles its parts (the date is a span of its own)
  defp text_of(html),
    do: html |> Floki.parse_document!() |> Floki.text(sep: " ") |> String.replace(~r/\s+/u, " ")

  test "without it, the notifications feed is HTML", %{conn: conn} do
    html = rendered(conn, "/notifications")

    # the positive first: the like is in the feed
    assert html =~ "a post of mine that gets liked"
    refute text_of(html) =~ as_email()
  end

  test "with it, the notifications feed's rows are their emails", %{conn: conn} do
    html = rendered(conn, "/notifications?_email_format=mjml")

    assert text_of(html) =~ as_email()
    assert html =~ "a post of mine that gets liked"
  end

  # rows already on the page keep their first render (chips filter what is loaded rather than render it again), so switching the view needs the page rendered again: waiting on how the choice is kept (a session toggle, read at mount, is the proposal in the notifications plan), since doing it in the per-navigation params hook was turned down
  @tag skip: "switching the email view on a page already shown needs the page rendered again; how the choice is kept is still to be decided"
  test "it stays on while browsing between chips, and goes off when asked", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/notifications?_email_format=mjml")
    render_async(view)

    # a chip's link carries no `_email_format`, which is what used to switch it back to HTML
    render_patch(view, "/notifications/reactions")
    render_async(view)
    assert text_of(render(view)) =~ as_email()

    render_patch(view, "/notifications?_email_format=html")
    render_async(view)
    refute text_of(render(view)) =~ as_email()
  end
end
