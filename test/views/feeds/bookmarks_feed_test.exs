defmodule Bonfire.UI.Social.Feeds.BookmarksFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Bookmarks
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # Alice creates a post
    alice_post_content = "This is Alice's post that I will bookmark"
    alice_post_attrs = %{post_content: %{html_body: alice_post_content}}

    {:ok, alice_post} =
      Posts.publish(current_user: alice, post_attrs: alice_post_attrs, boundary: "public")

    # Bob creates a post
    bob_post_content = "This is Bob's post that I won't bookmark"
    bob_post_attrs = %{post_content: %{html_body: bob_post_content}}

    {:ok, bob_post} =
      Posts.publish(current_user: bob, post_attrs: bob_post_attrs, boundary: "public")

    # Me bookmarks Alice's post
    {:ok, bookmark} = Bookmarks.bookmark(me, alice_post.id)

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

  test "Bookmarks feed shows only posts that I have bookmarked", %{
    conn: conn,
    me: me,
    alice_post_content: alice_post_content,
    bob_post_content: bob_post_content
  } do
    # Visit my bookmarks feed
    conn
    |> visit("/feed/bookmarks")

    # Test that Alice's post (which I bookmarked) appears in the feed
    |> assert_has("[data-id=feed] article")
    |> assert_has("[data-id=object_body]", text: alice_post_content)

    # Test that Bob's post (which I didn't bookmark) doesn't appear in the feed
    |> refute_has("[data-id=object_body]", text: bob_post_content)
  end

  test "Bookmarking and unbookmarking a post adds and removes it from bookmarks feed", %{
    conn: conn,
    me: me,
    bob: bob,
    bob_post: bob_post,
    alice_post_content: alice_post_content,
    bob_post_content: bob_post_content
  } do
    # First check bookmarks feed only has Alice's post
    conn
    |> visit("/feed/bookmarks")
    |> assert_has("[data-id=object_body]", text: alice_post_content)

    # |> refute_has("[data-id=object_body]", text: bob_post_content)

    # Now bookmark Bob's post
    {:ok, bookmark} = Bookmarks.bookmark(me, bob_post.id)

    # Check that both posts now appear in bookmarks feed
    conn
    |> visit("/feed/bookmarks")
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> assert_has("[data-id=object_body]", text: bob_post_content)

    # Unbookmark Bob's post
    {:ok, unbookmarked} = Bookmarks.unbookmark(me, bob_post.id)

    # Check that only Alice's post remains in bookmarks feed
    conn
    |> visit("/feed/bookmarks")
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> refute_has("[data-id=object_body]", text: bob_post_content)
  end
end
