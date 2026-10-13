defmodule Bonfire.UI.Social.PostEdit.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  use Bonfire.Common.E

  alias Bonfire.Posts
  alias Bonfire.Social.PostContents

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  defp open_edit(session) do
    session
    |> open_more_menu()
    |> click_button("[data-role=edit_post] [data-role=open_modal]", "Edit")
  end

  test "post author can see the edit option", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "editable post"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> open_more_menu()
    |> assert_has("[data-role=edit_post]", text: "Edit")
  end

  test "post author can edit post body", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "original body"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> open_edit()
    |> fill_in("Text", with: "updated body")
    |> click_button("Done")
    |> assert_has("[role=alert]", text: "Edited")

    assert {:ok, edited} = Posts.read(id(post), current_user: me)
    assert e(edited, :post_content, :html_body, nil) =~ "updated body"
  end

  test "post author can add a title via edit", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "post without title"}},
        boundary: "public"
      )

    conn
    |> visit("/discussion/#{post.id}")
    |> open_edit()
    |> fill_in("Title", with: "My New Title")
    |> click_button("Done")
    |> assert_has("[role=alert]", text: "Edited")

    assert {:ok, edited} = Posts.read(id(post), current_user: me)
    assert e(edited, :post_content, :name, nil) == "My New Title"
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
