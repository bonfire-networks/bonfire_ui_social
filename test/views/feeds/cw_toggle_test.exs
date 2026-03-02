defmodule Bonfire.UI.Social.CWToggle.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  test "CW post hides body behind toggle by default", %{conn: conn, me: me} do
    {:ok, _post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          sensitive: true,
          post_content: %{
            summary: "spoiler warning",
            html_body: "hidden spoiler content"
          }
        },
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> assert_has("[data-role=cw]", text: "spoiler warning")
    |> assert_has("[data-id=activity_note] div.hidden", text: "hidden spoiler content")
    |> assert_has(".show_more_toggle_action", text: "Show")
  end

  @tag :todo
  # The CW toggle button uses vanilla JS `onclick` (not `phx-click`),
  # so PhoenixTest cannot simulate the click event.
  test "clicking Show switches label to Hide", %{conn: conn, me: me} do
    {:ok, _post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          sensitive: true,
          post_content: %{
            summary: "toggle test cw",
            html_body: "revealed content"
          }
        },
        boundary: "public"
      )

    # The CW toggle is a <button> containing both the CW text and
    # a Show/Hide div. PhoenixTest's click_button matches by text
    # within the button element — "Show" text is inside the button.
    conn
    |> visit("/feed/local")
    |> assert_has(".show_more_toggle_action", text: "Show")
    |> click_button("Show")
    |> assert_has(".show_more_toggle_action", text: "Hide")
  end

  @tag :todo
  # The content visibility toggle uses vanilla JS `onclick` → `js_toggle`
  # which PhoenixTest cannot execute, so the full Show→Hide cycle
  # including content div visibility cannot be reliably tested here.
  test "full toggle cycle: Show then Hide", %{conn: conn, me: me} do
    {:ok, _post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{
          sensitive: true,
          post_content: %{
            summary: "cycle test cw",
            html_body: "cycle content"
          }
        },
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> click_button("Show")
    |> assert_has(".show_more_toggle_action", text: "Hide")
    |> click_button("Hide")
    |> assert_has(".show_more_toggle_action", text: "Show")
  end
end
