defmodule Bonfire.UI.Social.AdvancedActions.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Objects

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, me: me}
  end

  describe "advanced actions modal on discussion page" do
    test "the Advanced button is visible in the more-actions menu", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "test post for advanced actions"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("[data-id=boundary_details]")
    end

    @tag :todo
    # The modal content is only visible after JS interaction to open it,
    # which PhoenixTest cannot trigger on initial page load.
    test "boundary info section is present in the Advanced modal content", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "boundary info post"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> assert_has("h3", text: "Boundary")
    end
  end

  describe "edit post via advanced actions" do
    @tag :todo
    # object_boundary is loaded asynchronously via update_many on connected mount,
    # so boundary-dependent actions (Edit, Delete) inside the Advanced modal
    # don't render on the initial page load that PhoenixTest sees.
    test "post author can see the Edit button in advanced actions", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "editable via advanced"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> assert_has("button", text: "Edit")
    end

    @tag :todo
    # Depends on Edit button being visible (boundary async preload).
    test "post author can edit post body via advanced actions", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "original content"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> click_button("button", "Edit")
      |> fill_in("Text", with: "updated via advanced")
      |> click_button("Done")
      |> assert_has("[role=alert]", text: "Edited")
    end
  end

  describe "delete post via advanced actions" do
    @tag :todo
    # object_boundary is loaded asynchronously via update_many on connected mount.
    test "post author can see the Delete button in advanced actions", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "deletable via advanced"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> assert_has("button", text: "Delete")
    end

    @tag :todo
    # Depends on Delete button being visible (boundary async preload).
    test "post author can delete post via advanced actions", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "post to delete via advanced"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> click_button("button", "Delete post")
      |> click_button("Delete post")
      |> assert_has("[role=alert]", text: "Deleted")
    end

    test "deleted post disappears from feed", %{conn: conn, me: me} do
      body = "vanishing post #{System.unique_integer()}"

      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: body}},
          boundary: "public"
        )

      conn
      |> visit("/feed/local")
      |> assert_has("article", text: body)

      Objects.delete(post, current_user: me)

      conn
      |> visit("/feed/local")
      |> refute_has("article", text: body)
    end
  end

  describe "advanced actions on feed page" do
    test "Advanced button appears in more-actions menu on feed", %{conn: conn, me: me} do
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "feed post for advanced"}},
        boundary: "public"
      )

      conn
      |> visit("/feed/local")
      |> assert_has("[data-id=boundary_details]")
    end

    test "non-boundary actions still visible without boundary preload", %{conn: conn, me: me} do
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "feed post for copy link"}},
        boundary: "public"
      )

      conn
      |> visit("/feed/local")
      |> assert_has("[data-role=label]", text: "Copy link")
    end
  end

  describe "danger zone section" do
    @tag :todo
    # object_boundary is loaded asynchronously via update_many on connected mount.
    test "danger zone section shows for post author", %{conn: conn, me: me} do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: "danger zone test"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> assert_has("h3", text: "Danger zone")
    end

    @tag :todo
    # object_boundary is loaded asynchronously via update_many on connected mount.
    test "non-author cannot see delete in danger zone", %{conn: conn, me: me} do
      other_account = fake_account!()
      other_user = fake_user!(other_account)

      {:ok, post} =
        Posts.publish(
          current_user: other_user,
          post_attrs: %{post_content: %{html_body: "someone else's post"}},
          boundary: "public"
        )

      conn
      |> visit("/discussion/#{post.id}")
      |> click_button("[data-id=boundary_details]", "Advanced")
      |> refute_has("button", text: "Delete post")
    end
  end
end
