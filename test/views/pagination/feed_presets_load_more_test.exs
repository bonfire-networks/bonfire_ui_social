defmodule Bonfire.UI.Social.Feeds.FeedsPresets.PaginationTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  import Bonfire.Common.Simulation
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  alias Bonfire.Files.Media
  use Mneme
  import Untangle

  setup do
    limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
    # Create multiple users
    account = fake_account!()
    user1 = fake_user!(account)

    user2 = fake_user!(account)

    user3 = fake_user!(account)

    # Make user1 follow user2
    Follows.follow(user1, user2)

    %{
      user1: user1,
      user2: user2,
      user3: user3,
      account: account,
      limit: limit
    }
  end

  describe "Images Feed Pagination" do
    test "pagination loads the correct next set of image posts", %{
      user1: user1,
      account: account,
      user2: user2,
      limit: limit
    } do
      # Create more posts with images than the pagination limit
      total_posts = limit * 3

      # Create posts with images in reverse order (newest first)
      posts =
        Enum.map(total_posts..1, fn n -> Fake.create_test_content(:images, user1, user2, n) end)

      # Visit the images feed
      conn = conn(user: user1, account: account)

      conn
      |> visit("/feed/local_media")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article[data-id=activity]", count: limit)
      # Should have the newest posts (lowest numbers)
      |> assert_has_or_open_browser("article", text: "Image post 1")
      |> assert_has("article", text: "Image post 2")
      |> refute_has("article", text: "Image post #{limit + 1}")
      # Load next page with LiveView
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts
      |> assert_has("[data-id=feed] article[data-id=activity]", count: limit * 2)
      # Should include both old and new posts
      |> assert_has("article", text: "Image post 1")
      |> assert_has("article", text: "Image post #{limit + 1}")
      # Load final page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have all posts
      |> assert_has("[data-id=feed] article[data-id=activity]", count: total_posts)
      # Should include the oldest posts
      |> assert_has("article", text: "Image post #{total_posts}")
    end
  end

  describe "Following Feed Pagination" do
    test "pagination loads the correct next set of posts from followed users", %{
      user1: user1,
      user2: user2,
      user3: user3,
      account: account,
      limit: limit
    } do
      # Create more posts than the pagination limit from the followed user
      total_posts = round(limit * 1.5)

      # Create posts from myself (user1)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user1,
            post_attrs: %{
              post_content: %{
                html_body: "My own post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Create posts from followed user (user2)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "Followed user post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Create some posts from user3 (will not show in following feed)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user3,
            post_attrs: %{
              post_content: %{
                html_body: "Third party post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Visit following feed
      conn = conn(user: user1, account: account)

      conn
      |> visit("/feed/my")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article", count: limit)
      # Only posts from followed users should appear
      |> assert_has("article", text: "Followed user post")
      #   |> assert_has_or_open_browser("article", text: "My own post")
      |> refute_has("article", text: "Third party post")
      # Load next page using WebSocket
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts, all from followed users
      |> assert_has("[data-id=feed] article", count: limit * 2)
      # Still only followed user posts
      |> assert_has("article", text: "Followed user post")
      |> refute_has("article", text: "Third party post")
      |> assert_has_or_open_browser("article", text: "My own post")
      # Count occurrences of the text "Followed user post"
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/Followed user post/, html) |> length() == total_posts
        html
      end)
    end
  end

  describe "Circle Feed Pagination" do
    test "pagination loads the correct next set of posts from circle members", %{
      user1: user1,
      user2: user2,
      account: account,
      limit: limit
    } do
      # Create a circle owned by user1
      {:ok, circle} =
        Bonfire.Boundaries.Circles.create(user1, %{
          named: %{name: "Pagination Test Circle"}
        })

      # Add user2 to circle
      {:ok, _} = Bonfire.Boundaries.Circles.add_to_circles(user2, circle)

      # share the circle
      Bonfire.Social.Objects.publish(user1, :boost, circle,
        to_boundaries: "local"
        #  to_circles: 
      )

      # Create more posts than the pagination limit from the circle member
      total_posts = limit * 3

      # Create posts from circle member (user2)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "Circle member post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Visit circle feed
      conn = conn(user: user1, account: account)

      conn
      |> visit("/circle/#{circle.id}")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article", count: limit)
      # Only circle member posts should appear
      |> assert_has("article", text: "Circle member post")
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit * 2)
      # Verify all loaded posts are from circle members
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/Circle member post/, html) |> length() == limit * 2
        html
      end)
    end
  end

  describe "Hashtag Feed Pagination" do
    test "pagination loads the correct next set of posts with specific hashtag", %{
      user1: user1,
      account: account,
      limit: limit
    } do
      # Create more posts than the pagination limit with a specific hashtag
      total_posts = limit * 3
      hashtag = "PaginationTest"

      # Create posts with hashtag
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user1,
            post_attrs: %{
              post_content: %{
                html_body: "Post with ##{hashtag} number #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Create posts without hashtag
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user1,
            post_attrs: %{
              post_content: %{
                html_body: "Regular post number #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Visit hashtag feed
      conn = conn(user: user1, account: account)

      conn
      |> visit("/hashtag/#{hashtag}")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article", count: limit)
      # Only hashtag posts should appear
      |> assert_has("article", text: "##{hashtag}")
      |> refute_has("article", text: "Regular post")
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit * 2)
      # Verify all loaded posts contain the hashtag
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/##{hashtag}/, html) |> length() >= limit * 2
        html
      end)
    end
  end

  describe "Notifications Feed Pagination" do
    test "pagination loads the correct next set of notifications", %{
      user1: user1,
      user2: user2,
      account: account,
      limit: limit
    } do
      # Create more posts than the pagination limit
      total_posts = limit * 3

      # Create posts by user1
      posts =
        for n <- 1..total_posts do
          {:ok, post} =
            Posts.publish(
              current_user: user1,
              post_attrs: %{
                post_content: %{
                  html_body: "Original post #{n}"
                }
              },
              boundary: "public"
            )

          post
        end

      # Generate notifications by having user2 like and reply to posts
      for post <- posts do
        # Like to generate notification
        {:ok, _like} = Likes.like(user2, post)

        # Reply to generate notification
        {:ok, _reply} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "@#{user1.character.username} Reply with mention to post #{post.id}"
              },
              reply_to_id: post.id
            },
            boundary: "public"
          )
      end

      # Visit notifications
      conn = conn(user: user1, account: account)

      conn
      |> visit("/notifications")
      |> wait_async()
      # Should have pagination limit number of notifications
      |> assert_has("[data-id=feed] article", count: limit)
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more notifications
      |> assert_has("[data-id=feed] article", count: limit * 2)
      # Load final pages
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have all notifications
      |> assert_has("[data-id=feed] article", count: total_posts * 2)
    end
  end

  describe "My Feed Pagination" do
    test "pagination loads the correct next set of my own posts", %{
      user1: user1,
      user2: user2,
      user3: user3,
      account: account,
      limit: limit
    } do
      # Create more posts than the pagination limit
      total_posts = limit * 3

      # Create posts from user2
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "Following post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Create posts from user3 (should not appear in my feed)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user3,
            post_attrs: %{
              post_content: %{
                html_body: "Other user post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Visit my feed
      conn = conn(user: user1, account: account)

      conn
      |> visit("/feed/my")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article", count: limit)
      # Only my posts should appear
      |> assert_has("article", text: "Following post")
      |> refute_has("article", text: "Other user post")
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts, all mine
      |> assert_has("[data-id=feed] article", count: limit * 2)
      # Still only my posts
      |> assert_has("article", text: "Following post")
      |> refute_has("article", text: "Other user post")
      # Count occurrences of the text "Following post"
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/Following post/, html) |> length() == limit * 2
        html
      end)
    end
  end

  describe "Filter Persistence Through Pagination" do
    test "custom filters persist when loading more posts", %{
      user1: user1,
      account: account,
      user2: user2,
      limit: limit
    } do
      total_posts = limit * 3

      for n <- 1..total_posts do
        # Create text posts
        {:ok, _post} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "Text post #{n}"
              }
            },
            boundary: "public"
          )

        # Create image posts
        {_media, _post} = Fake.create_test_content(:images, user2, nil, n)
        nil
      end

      # Visit local feed with image filter
      conn = conn(user: user1, account: account)

      conn
      #   |> visit("/feed/local?content_type=images")
      |> visit("/feed/local")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has("[data-id=feed] article[data-id=activity]", count: limit)
      # Apply the filter
      |> click_button("[data-toggle='image'] button", "Only")
      |> wait_async()
      # Only image posts should appear
      |> assert_has_or_open_browser("article [data-role=name]", text: "Image post")
      |> refute_has_or_open_browser("article[data-id=activity]", text: "Text post")
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts, all images
      |> assert_has("[data-id=feed] article[data-id=activity]", count: limit * 2)
      # Still only image posts
      |> assert_has("article [data-role=name]", text: "Image post")
      |> refute_has("article[data-id=activity]", text: "Text post")
      # Count occurrences of the text "Image post"
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/Image post/, html) |> length() == limit * 2
        html
      end)

      # now do the same with the user profile
      conn
      |> visit("/@#{user2.character.username}")
      |> wait_async()
      # Apply the filter
      |> click_button("[data-toggle='image'] button", "Only")
      |> wait_async()
      # Should have pagination limit number of posts
      |> assert_has_or_open_browser("[data-id=feed] article[data-id=activity]", count: limit)
      # Only image posts should appear
      |> assert_has_or_open_browser("article[data-id=activity]", text: "Image post")
      |> refute_has_or_open_browser("article[data-id=activity]", text: "Text post")
      # |> PhoenixTest.open_browser()
      # Load next page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now should have more posts, all images
      |> assert_has("[data-id=feed] article[data-id=activity]", count: limit * 2)
      # Still only image posts
      |> assert_has("article [data-role=name]", text: "Image post")
      |> refute_has("article[data-id=activity]", text: "Text post")
      # Count occurrences of the text "Image post"
      |> unwrap(fn view ->
        html = render(view)
        assert Regex.scan(~r/Image post/, html) |> length() == limit * 2
        html
      end)
    end

    test "loads more posts from the correct feed", %{
      user1: user1,
      user2: user2,
      user3: user3,
      account: account,
      limit: limit
    } do
      total_posts = limit * 3

      # Create posts from followed user
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user2,
            post_attrs: %{
              post_content: %{
                html_body: "Followed user post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Create posts from non-followed user (should be filtered out)
      for n <- 1..total_posts do
        {:ok, _post} =
          Posts.publish(
            current_user: user3,
            post_attrs: %{
              post_content: %{
                html_body: "Third party post #{n}"
              }
            },
            boundary: "public"
          )
      end

      # Visit following feed with infinite scroll
      conn = conn(user: user1, account: account)

      conn
      |> visit("/feed/my")
      |> wait_async()
      # Check initial feed state - should see only followed user posts
      |> assert_has("[data-id=feed] article", count: limit)
      |> assert_has("[data-id=feed]", text: "Followed user post")
      |> refute_has("[data-id=feed]", text: "Third party post")
      # Trigger first infinite scroll load via the hook
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Verify the feed has correctly loaded more posts while maintaining filters
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit * 2)
      # Check a specific post that should be in second batch
      |> assert_has("[data-id=feed]", text: "Followed user post 3")
      |> refute_has("[data-id=feed]", text: "Third party post")
      # Trigger second infinite scroll load
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Verify the feed now contains all posts (still maintaining filters)
      |> assert_has_or("[data-id=feed] article", [count: total_posts], fn session ->
        session
        |> PhoenixTest.open_browser()
        |> click_button("[data-id=load_more]", "Load more")
        |> wait_async()
      end)
      # Check oldest post is now loaded
      |> assert_has("[data-id=feed]", text: "Followed user post #{total_posts}")
      |> refute_has("[data-id=feed]", text: "Third party post")
      # Verify we have the expected number of posts from followed user
      |> unwrap(fn view ->
        html = render(view)

        count =
          html |> Floki.parse_document!() |> Floki.find("[data-id=feed] article") |> length()

        assert count == total_posts

        # Check we only have posts from followed users
        followed_post_count = Regex.scan(~r/Followed user post/, html) |> length()
        assert followed_post_count == total_posts

        html
      end)
    end
  end
end
