defmodule Bonfire.UI.Social.PostDelete.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  @tag :todo
  # object_boundary is loaded asynchronously via update_many on connected mount,
  # so the delete button doesn't render on the initial page load that PhoenixTest sees.
  test "post author can see the delete button", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "deletable post"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("[role=delete]")
  end

  @tag :todo
  # Depends on delete button being visible (see above).
  test "post author can delete via confirmation modal", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "post to delete"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> click_button("[role=delete]", "Delete")
    |> click_button("Delete")
    |> assert_has("[role=alert]", text: "Deleted")
  end

  test "deleted post disappears from feed", %{conn: conn, me: me} do
    body = "post that will vanish #{System.unique_integer()}"

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: body}},
        boundary: "public"
      )

    # Verify it appears first
    conn
    |> visit("/feed/local")
    |> assert_has("article", text: body)

    # Delete via API
    Bonfire.Social.Objects.delete(post, current_user: me)

    # Verify it's gone
    conn
    |> visit("/feed/local")
    |> refute_has("article", text: body)
  end
end
