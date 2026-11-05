defmodule Bonfire.UI.Social.Feeds.LikesFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
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

  describe "filters on Likes" do
    # a tagged post I liked, a plain post I liked, a tagged post someone else liked, and a tagged post nobody liked: the hashtag filter acts on the liked post, and Likes on who liked it
    setup %{me: me, alice: alice, bob: bob} do
      tagged =
        Bonfire.Posts.Fake.fake_post!(alice, "public", %{
          post_content: %{html_body: "about #noctilucent clouds"}
        })

      plain =
        Bonfire.Posts.Fake.fake_post!(alice, "public", %{
          post_content: %{html_body: "a plain post I liked"}
        })

      bobs =
        Bonfire.Posts.Fake.fake_post!(bob, "public", %{
          post_content: %{html_body: "another #noctilucent post"}
        })

      Bonfire.Posts.Fake.fake_post!(alice, "public", %{
        post_content: %{html_body: "unliked #noctilucent post"}
      })

      {:ok, _} = Likes.like(me, tagged.id)
      {:ok, _} = Likes.like(me, plain.id)
      {:ok, _} = Likes.like(bob, bobs.id)

      :ok
    end

    defp filter_by_noctilucent(session) do
      session
      |> click_button("[data-role=open_modal]", "More filters")
      |> fill_in("Hashtags", with: "noctilucent")
      |> click_button("Apply filters")
      |> wait_async()
    end

    defp refute_other_likes(session) do
      session
      |> refute_has("[data-id=object_body]", text: "a plain post I liked")
      |> refute_has("[data-id=object_body]", text: "another #noctilucent post")
      |> refute_has("[data-id=object_body]", text: "unliked #noctilucent post")
    end

    test "Likes shows the feed controls, without activity type, people, Replies or Boosts", %{
      conn: conn
    } do
      conn
      |> visit("/feed/likes")
      |> wait_async()
      |> assert_has("[data-role=feed_advanced_filters]")
      |> refute_has("input[name='scope[replies]']")
      |> refute_has("input[name='scope[boosts]']")
      |> click_button("[data-role=open_modal]", "More filters")
      |> assert_has("[data-row=hashtags]")
      |> refute_has("[data-row=activity_types]")
      |> refute_has("[data-row=hide_own]")
      |> refute_has("[data-row=from_people]")
      |> refute_has("[data-row=not_people]")
    end

    test "a hashtag narrows Likes to my liked posts with it", %{conn: conn} do
      conn
      |> visit("/feed/likes")
      |> wait_async()
      |> filter_by_noctilucent()
      |> assert_has("[data-id=object_body]", text: "about #noctilucent clouds")
      |> refute_other_likes()
    end

    test "a feed saved from a filtered Likes reopens with only my likes with that tag", %{
      conn: conn
    } do
      name = "saved-likes-" <> to_string(System.unique_integer([:positive]))

      conn
      |> visit("/feed/likes")
      |> wait_async()
      |> filter_by_noctilucent()
      |> fill_in("Feed title", with: name)
      |> click_button("Save feed")
      |> visit("/settings/user/feeds")
      |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
      |> wait_async()
      |> assert_has("#feed-description-title", text: name)
      |> assert_has("[data-id=object_body]", text: "about #noctilucent clouds")
      |> refute_other_likes()
    end
  end
end
