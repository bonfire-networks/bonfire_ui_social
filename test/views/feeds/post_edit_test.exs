defmodule Bonfire.UI.Social.PostEdit.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.PostContents

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  @tag :todo
  # object_boundary is loaded asynchronously via update_many on connected mount,
  # so the edit option doesn't render on the initial page load that PhoenixTest sees.
  test "post author can see the edit option", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "editable post"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("li", text: "Edit")
  end

  @tag :todo
  # Depends on edit option being visible (see above).
  test "post author can edit post body", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "original body"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> click_button("li", "Edit")
    |> fill_in("Text", with: "updated body")
    |> click_button("Done")
    |> assert_has("[role=alert]", text: "Edited")
  end

  @tag :todo
  # Depends on edit option being visible (see above).
  test "post author can add a title via edit", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "post without title"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> click_button("li", "Edit")
    |> fill_in("Title", with: "My New Title")
    |> click_button("Done")
    |> assert_has("[role=alert]", text: "Edited")
  end

  test "edited post shows updated content via API", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "before edit"}},
        boundary: "public"
      )

    {:ok, _edited} =
      PostContents.edit(me, post, %{html_body: "after edit"})

    conn
    |> visit("/discussion/#{post.id}")
    |> assert_has("article", text: "after edit")
  end
end
