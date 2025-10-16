defmodule Bonfire.UI.Social.Feeds.ProfileFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    me = fake_user!("meee")
    alice = fake_user!("alice")

    # alice creates a post
    alice_post_content = "This is Alice's post"
    alice_post_attrs = %{post_content: %{html_body: alice_post_content}}

    {:ok, alice_post} =
      Posts.publish(current_user: alice, post_attrs: alice_post_attrs, boundary: "public")

    # I boost alice's post
    {:ok, boost} = Boosts.boost(me, alice_post.id)

    # I create a post
    my_post_content = "This is my original post"
    my_post_attrs = %{post_content: %{html_body: my_post_content}}

    {:ok, my_post} =
      Posts.publish(current_user: me, post_attrs: my_post_attrs, boundary: "public")

    conn = conn(user: me)

    {:ok,
     conn: conn,
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
    # |> PhoenixTest.open_browser()

    # Test that both my post and my boost of alice's post are in the feed
    # |> assert_has("article", count: 2)

    |> assert_has("[data-id=object_body]", text: my_post_content)
    # The boosted content should appear too
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
    # |> assert_has("article", count: 1)
    |> assert_has("[data-id=object_body]", text: alice_post_content)
    |> refute_has("[data-id=object_body]", text: my_post_content)
  end

  # doesn't work because the boost still has a post as object
  test "can filter the profile feed by post only", %{
    conn: conn,
    me: me,
    alice: alice,
    my_post_content: my_post_content,
    alice_post_content: alice_post_content
  } do
    # Create image posts
    {_media, _post} = Fake.create_test_content(:image_post, me, nil)

    # connect as alice
    conn = conn(user: alice)

    # alice visits my profile feed
    conn
    |> visit("/user/#{me.id}")
    |> assert_has("[data-id=feed_controls]")
    |> assert_has_or_open_browser("[data-id=object_body]", text: my_post_content)
    |> assert_has("article [data-role=name]", text: "Image post")

    #  then we hide images
    |> click_button("[data-toggle=image] button", "Hide")
    |> wait_async()
    |> assert_has_or_open_browser("[data-id=object_body]", text: my_post_content)
    |> refute_has_or_open_browser("article [data-role=name]", text: "Image post")

    #  then we hide posts
    |> click_button("[data-toggle=post] button", "Hide")
    |> wait_async()
    # |> PhoenixTest.open_browser()
    # should have nothing left
    |> refute_has("[data-id=feed] article", text: "This is my original post")
  end
end
