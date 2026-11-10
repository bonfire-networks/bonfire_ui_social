defmodule Bonfire.UI.Social.PreviewOpenClose.Test do
  @moduledoc """
  Opening a post from a feed into the preview (`Bonfire.UI.Common.PreviewContentLive`) and closing it, pushing the events the client hook pushes.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  use Bonfire.Common.E

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)

    {:ok, conn: conn, me: me}
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

  # the post's `OpenModalLive` wrapper, whose id ends in `open_preview_<object id>`
  defp open_preview(view, post) do
    view
    |> with_target(~s([id$="open_preview_#{id(post)}"]))
    |> render_hook("open", %{"previous_url" => "/feed/local", "previous_scroll" => 0})

    # content and layout arrive as messages handled after the event
    render(view)
  end

  defp close_preview(view) do
    view |> with_target("#preview_content") |> render_hook("close", %{})
    render(view)
  end

  defp preview_html(view), do: view |> element("#preview_content") |> render()

  test "the tapped post's content shows in the preview, not the loader", %{conn: conn, me: me} do
    post = publish!(me, "previewed post body")
    {:ok, view, _html} = live(conn, "/feed/local")

    open_preview(view, post)

    assert preview_html(view) =~ "previewed post body"
    refute preview_html(view) =~ "Loading..."
  end

  test "closing clears the preview, so the next post opened never shows the last one",
       %{conn: conn, me: me} do
    first = publish!(me, "first previewed post")
    {:ok, view, _html} = live(conn, "/feed/local")

    open_preview(view, first)
    # control: it was showing
    assert preview_html(view) =~ "first previewed post"

    close_preview(view)

    refute preview_html(view) =~ "first previewed post"
  end

  test "a patch navigation that hides the preview clears it too", %{conn: conn, me: me} do
    post = publish!(me, "previewed then patched away")
    {:ok, view, _html} = live(conn, "/feed/local")

    open_preview(view, post)
    # control: it was showing
    assert preview_html(view) =~ "previewed then patched away"

    render_patch(view, "/feed/local?patched=1")

    refute preview_html(view) =~ "previewed then patched away"
  end
end
