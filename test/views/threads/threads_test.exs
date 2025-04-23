defmodule Bonfire.Social.Threads.ThreadsTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other_account = fake_account!()
    other_user = fake_user!(other_account)

    # Create a post
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Original post"}},
        boundary: "public"
      )

    conn = conn(user: me, account: account)

    {:ok, conn: conn, me: me, other_user: other_user, post: post, other_account: other_account}
  end

  # test "when opening a post from another user profile, the main post subject is shown", %{
  #   other_user: other_user,
  #   me: me,
  #   other_account: other_account,
  #   post: post
  # } do
  #   conn = conn(user: other_user, account: other_account)
  #   conn
  #   |> visit("/@#{me.character.username}")
  #   |> unwrap(fn view ->
  #     view |> element("a", "activity timestamp")
  #     |> render_click()
  #   end)
  #   |> PhoenixTest.open_browser()
  # end

  test "replies to the original post appear instantly", %{
    conn: conn,
    post: post,
    other_user: other_user
  } do
    post_view =
      conn
      |> visit("/post/#{post.id}")

    attrs_reply = %{
      post_content: %{html_body: "First reply"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    post_view
    # |> PhoenixTest.open_browser()
    |> assert_has("article", text: "First reply")
  end

  test "replies to comments appear instantly", %{conn: conn, post: post, other_user: other_user} do
    post_view =
      conn
      |> visit("/post/#{post.id}")

    attrs_reply = %{
      post_content: %{html_body: "First reply"},
      reply_to_id: post.id
    }

    {:ok, reply} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply, boundary: "public")

    attrs_reply2 = %{
      post_content: %{html_body: "Second reply"},
      reply_to_id: post.id
    }

    {:ok, reply2} =
      Posts.publish(current_user: other_user, post_attrs: attrs_reply2, boundary: "public")

    post_view
    |> assert_has("article", text: "Second reply")
  end
end
