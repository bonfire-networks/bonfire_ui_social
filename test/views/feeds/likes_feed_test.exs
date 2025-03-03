defmodule Bonfire.UI.Social.Feeds.LikesFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Likes
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # Alice creates a post
    alice_post_content = "This is Alice's post that I will like"
    alice_post_attrs = %{post_content: %{html_body: alice_post_content}}

    {:ok, alice_post} =
      Posts.publish(current_user: alice, post_attrs: alice_post_attrs, boundary: "public")

    # Bob creates a post
    bob_post_content = "This is Bob's post that I won't like"
    bob_post_attrs = %{post_content: %{html_body: bob_post_content}}

    {:ok, bob_post} =
      Posts.publish(current_user: bob, post_attrs: bob_post_attrs, boundary: "public")

    # Me likes Alice's post
    {:ok, like} = Likes.like(me, alice_post.id)

    conn = conn(user: me, account: account)

    {:ok,
     conn: conn,
     account: account,
     alice: alice,
     bob: bob,
     me: me,
     alice_post: alice_post,
     bob_post: bob_post,
     alice_post_content: alice_post_content,
     bob_post_content: bob_post_content}
  end

  test "Likes feed shows only posts that I have liked", %{
    conn: conn,
    me: me,
    alice_post_content: alice_post_content,
    bob_post_content: bob_post_content
  } do
    # Visit my likes feed
    conn
    |> visit("/feed/likes")

    # Test that Alice's post (which I liked) appears in the feed
    |> assert_has("[data-id=feed] article")
    |> assert_has("[data-id=object_body]", text: alice_post_content)

    # Test that Bob's post (which I didn't like) doesn't appear in the feed
    |> refute_has("[data-id=object_body]", text: bob_post_content)
  end

  test "Liking and unliking a post adds and removes it from likes feed", %{
    conn: conn,
    me: me,
    bob: bob,
    bob_post: bob_post,
    alice_post_content: alice_post_content,
    bob_post_content: bob_post_content
  } do
    # First check likes feed only has Alice's post
    conn
    |> visit("/feed/likes")
    |> assert_has("[data-id=object_body]", text: alice_post_content)

    # |> refute_has("[data-id=object_body]", text: bob_post_content)

    # Now like Bob's post
    {:ok, like} = Likes.like(me, bob_post.id)

    # Check that both posts now appear in likes feed
    conn
    |> visit("/feed/likes")
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> assert_has("[data-id=object_body]", text: bob_post_content)

    # Unlike Bob's post
    Likes.unlike(me, bob_post.id)

    # Check that only Alice's post remains in likes feed
    conn
    |> visit("/feed/likes")
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> refute_has("[data-id=object_body]", text: bob_post_content)
  end
end
