defmodule Bonfire.Social.Threads.ThreadsTest do
  use Bonfire.UI.Social.ConnCase, async: true
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
    {:ok, post} = Bonfire.Posts.create(me, %{post_content: %{html_body: "Original post"}})

    # Create a first-level reply
    {:ok, reply} =
      Bonfire.Posts.reply(other_user, post, %{post_content: %{html_body: "First reply"}})

    conn = conn(user: me, account: account)

    {:ok, conn: conn, me: me, other_user: other_user, post: post, reply: reply}
  end

  test "replies to the original post appear instantly", %{conn: conn, post: post} do
    conn
    |> visit("/post/#{post.id}")
    |> fill_in("Write a comment...", with: "My reply to the original post")
    |> click_button("Reply")
    |> assert_has(".comment", text: "My reply to the original post")
  end

  test "replies to comments appear instantly", %{conn: conn, post: post, reply: reply} do
    conn
    |> visit("/post/#{post.id}")
    # First, ensure the first-level reply is visible
    |> assert_has(".comment", text: "First reply")
    # Click the reply button on the first-level reply
    |> click_button("[data-reply-to='#{reply.id}']", "Reply")
    |> fill_in("Write a comment...", with: "Reply to the comment")
    |> click_button("Reply")
    # Assert that the new reply appears without a page refresh
    |> assert_has(".comment .comment", text: "Reply to the comment")
  end
end
