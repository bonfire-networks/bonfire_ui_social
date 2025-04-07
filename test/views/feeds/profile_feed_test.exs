defmodule Bonfire.UI.Social.Feeds.ProfileFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)

    # me creates a post
    my_post_content = "This is my original post"
    my_post_attrs = %{post_content: %{html_body: my_post_content}}

    {:ok, my_post} =
      Posts.publish(current_user: me, post_attrs: my_post_attrs, boundary: "public")

    # alice creates a post
    alice_post_content = "This is Alice's post"
    alice_post_attrs = %{post_content: %{html_body: alice_post_content}}

    {:ok, alice_post} =
      Posts.publish(current_user: alice, post_attrs: alice_post_attrs, boundary: "public")

    # me boosts alice post
    {:ok, boost} = Boosts.boost(me, alice_post.id)

    conn = conn(user: me, account: account)

    {:ok,
     conn: conn,
     account: account,
     alice: alice,
     me: me,
     my_post: my_post,
     alice_post: alice_post,
     my_post_content: my_post_content,
     alice_post_content: alice_post_content}
  end

  test "Profile feed shows activities by the user", %{
    conn: conn,
    me: me,
    alice: alice,
    my_post_content: my_post_content,
    alice_post_content: alice_post_content
  } do
    # Visit my profile feed
    conn
    |> visit("/user")
    |> PhoenixTest.open_browser()

    # Test that both my post and my boost of alice's post are in the feed
    # |> assert_has("article", count: 2)

    |> assert_has("[data-id=object_body]", text: my_post_content)
    # The boosted content should appear
    |> assert_has("[data-id=object_body]", text: alice_post_content)
  end

  test "Profile feed does not show activities by another user", %{
    conn: conn,
    me: me,
    alice: alice,
    my_post_content: my_post_content,
    alice_post_content: alice_post_content
  } do
    # Test that only my activities (my post & my boost) are in the feed
    # Visit alice's profile to verify her post doesn't show in my profile
    conn
    |> visit("/user/#{alice.id}")
    |> assert_has("article", count: 1)
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> refute_has("[data-id=object_body]", text: my_post_content)
  end

  # doesn't work because the boost still has a post as object
  @tag :fixme
  test "can filter the profile feed by post only", %{
    conn: conn,
    me: me,
    alice: alice,
    my_post_content: my_post_content,
    alice_post_content: alice_post_content
  } do
    # Visit my profile feed
    conn
    |> visit("/user")

    # First verify both my original post and boosted content appear
    # |> assert_has("[data-id=feed] article", count: 2)
    # |> assert_has("[data-id=object_body]", text: my_post_content)
    # |> assert_has("[data-id=object_body]", text: alice_post_content)

    # Click the "Hide" button for boosts

    |> assert_has("[data-id=feed_controls]")
    |> click_button("[data-toggle=boost] button", "Hide")

    # Test that my boost does not appear after filtering
    |> refute_has("[data-id=object_body]", text: alice_post_content)

    # Test that my post still appears
    |> assert_has("[data-id=object_body]", text: my_post_content)
    |> assert_has("[data-id=feed] article", count: 1)
  end
end
