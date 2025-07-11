defmodule Bonfire.UI.Social.FeedsFilters.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  import Bonfire.Files.Simulation
  use Bonfire.Common.Repo

  setup do
    _ = fake_admin!()
    user = fake_user!("test user")
    other_user = fake_user!("other user")
    {:ok, %{user: user, other_user: other_user}}
  end

  # describe "tabs filter buttons UI" do
  # test "User can switch between feed tabs", %{user: user, other_user: other_user} do
  #   # Create some test content to ensure tabs are populated
  #   Bonfire.Common.Config.put(:default_pagination_limit, 6)
  #   Fake.create_test_content(:likes, user, other_user)
  #   Fake.create_test_content(:bookmarks, user, other_user)
  #   Fake.create_test_content(:image_post, user, other_user)
  #   {post, _} = Fake.create_test_content(:local, user, other_user)
  #   # boost it
  #   {:ok, boost} = Boosts.boost(user, post)

  #   popular_post =
  #     fake_post!(user, "public", %{
  #       post_content: %{name: "default post", html_body: "content https://example.com"}
  #     })

  #   less_popular_post =
  #     fake_post!(user, "public", %{
  #       post_content: %{name: "default post", html_body: "content"}
  #     })

  #   conn(user: user)
  #   |> visit("/feed/explore")
  #   |> assert_has("[data-id=feed] .activity_wrapper", count: 5)
  #   |> click_button("[data-id=filter-boosts]", "Boosts")
  #   |> assert_has("[data-id=feed] .activity_wrapper", count: 1)
  #   |> assert_has("[data-id=feed] [data-role=boosted_by]")
  #   |> click_button("[data-id=filter-images]", "Images")
  #   |> assert_has("[data-id=feed] .activity_wrapper", count: 1)
  #   |> assert_has("article img")
  # end

  # test "User can switch between feed tabs from mobile", %{user: user, other_user: other_user} do
  #   # Create some test content to ensure tabs are populated
  #   Bonfire.Common.Config.put(:default_pagination_limit, 6)
  #   Fake.create_test_content(:likes, user, other_user)
  #   Fake.create_test_content(:bookmarks, user, other_user)
  #   Fake.create_test_content(:image_post, user, other_user)
  #   {post, _} = Fake.create_test_content(:local, user, other_user)
  #   # boost it
  #   {:ok, boost} = Boosts.boost(user, post)

  #   popular_post =
  #     fake_post!(user, "public", %{
  #       post_content: %{name: "default post", html_body: "content https://example.com"}
  #     })

  #   less_popular_post =
  #     fake_post!(user, "public", %{
  #       post_content: %{name: "default post", html_body: "content"}
  #     })

  #   conn(user: user)
  #   |> visit("/feed/explore")
  #   |> assert_has("[data-id=feed] .activity_wrapper", count: 5)
  #   |> within("#form_filter_select", fn session ->
  #     session
  #     |> PhoenixTest.select("Filter", option: "Show Boosts")
  #   end)
  #   |> assert_has("[data-id=feed] [data-role=boosted_by]")
  #   |> within("#form_filter_select", fn session ->
  #     session
  #     |> PhoenixTest.select("Filter", option: "Show Images")
  #   end)
  #   |> assert_has("article img")
  # end
  # end

  describe "feed filters UI:" do
    test "user can toggle filter options", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # Open filters section
      # |> click_button("Filters")
      # Toggle boost and follow filters

      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-toggle='boost'] [data-id='enabled'].active")
      |> click_button("[data-toggle='boost'] button", "Hide")
      |> assert_has("[data-toggle='boost'] [data-id='disabled'].active")
      |> click_button("[data-toggle='boost'] button", "Include")
      |> assert_has("[data-toggle='boost'] [data-id='default'].active")
    end

    @tag :todo
    # if this is desired?
    test "filters persist after navigation", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # |> click_button("Filters")
      # Set some filters
      |> within("[data-scope='time_limit']", fn session ->
        session
        |> choose("Time limit control", option: "Day")
      end)
      |> click_button("[data-toggle='boost'] button", "Only")
      # Navigate to another feed
      |> click_link("nav [data-id=nav_links] a", "Local")
      |> assert_path("/feed/local")
      # Verify filters are still applied
      # Boosts checked
      |> assert_has("[data-toggle='boost'] [data-id='enabled'].active")
      # Day selected
      |> assert_has("[data-scope='time_limit'] input[value='1']:checked")
    end
  end

  describe "following feed" do
    test "shows posts from followed users", %{user: user, other_user: other_user} do
      # Create test content for following feed
      {post, _} = Fake.create_test_content(:my, user, other_user)

      conn(user: user)
      |> visit("/feed/my")
      |> assert_has("[data-id=feed] article", text: "content from someone I follow")
      |> assert_has("[data-id=feed] article", text: other_user.character.username)
    end
  end

  describe "bookmarks feed" do
    test "shows bookmarked posts", %{user: user, other_user: other_user} do
      {post, _} = Fake.create_test_content(:bookmarks, user, other_user)

      conn(user: user)
      |> visit("/feed/bookmarks")
      |> assert_has("[data-id=feed] article", text: "bookmarkable post")
    end
  end

  # describe "mentions feed" do
  #   test "shows posts mentioning the user", %{user: user, other_user: other_user} do
  #     {post, _} = Fake.create_test_content(:mentions, user, other_user)

  #     conn(user: user)
  #     |> visit("/feed/mentions")
  #     |> assert_has("[data-id=feed] article", text: "@#{user.character.username}")
  #   end
  # end

  describe "hashtag feed" do
    test "shows posts with specific hashtags, and ensure the subject is preloaded in hashtags feed",
         %{user: user, other_user: other_user} do
      {post, _} = Fake.create_test_content(:hashtag, user, other_user)

      conn(user: user)
      |> visit("/hashtag/test")
      # |> PhoenixTest.open_browser()
      |> assert_has("[data-id=feed] article", text: "#test")
      |> assert_has("[data-id=subject_name]", text: "#{user.profile.name}")
    end
  end

  describe "local feed" do
    test "shows local posts", %{user: user, other_user: other_user} do
      {post, _} = Fake.create_test_content(:local, user, other_user)

      conn(user: user)
      |> visit("/feed/local")
      |> assert_has("[data-id=feed] article", text: "default post")
    end

    test "filtering by boost-only it correctly preloads the subject and creator", %{
      user: user,
      other_user: other_user
    } do
      # create a post
      {post, _} = Fake.create_test_content(:local, user, other_user)
      # boost it
      {:ok, boost} = Boosts.boost(user, post)
      # check the feed
      conn(user: user)
      |> visit("/feed/explore")
      # |> PhoenixTest.open_browser()
      # |> assert_has_or_open_browser("[data-id=feed] article[data-verb=Boost]", text: "default post")
      |> click_button("[data-toggle='boost'] button", "Only")
      # |> PhoenixTest.open_browser()
      |> assert_has_or_open_browser("[data-id=feed] article[data-verb=Boost]",
        text: "default post"
      )
      |> assert_has("[data-id=subject_name]", text: "#{other_user.profile.name}")
      |> assert_has("[data-id=subject_username]", text: "#{other_user.character.username}")
      |> assert_has("[data-id=subject_name]", text: "#{user.profile.name}")

      # |> assert_has("[data-id=subject_username]", text: "#{user.character.username}")
    end
  end

  describe "liked content feed" do
    test "shows posts liked by user", %{user: user, other_user: other_user} do
      {post, like} = Fake.create_test_content(:likes, user, other_user)

      conn(user: user)
      |> visit("/feed/likes")
      |> assert_has("[data-id=feed] article", text: "likeable post")
    end
  end

  describe "media feed" do
    test "shows local images", %{user: user, other_user: other_user} do
      {post1, _} = Fake.create_test_content(:local, user, other_user)

      {media, _post} = Fake.create_test_content(:image_post, user, other_user)

      conn(user: user)
      |> visit("/feed/images")
      # |> PhoenixTest.open_browser()
      |> assert_has("article [data-id=article_media]")
      |> refute_has("article", text: "default post")
    end
  end

  describe "flagged content feed" do
    test "shows posts flagged by me", %{user: user, other_user: other_user} do
      {post, flag} = Fake.create_test_content(:my_flags, user, other_user)

      conn(user: user)
      |> visit("/settings/user/flags")
      |> assert_has("[data-id=feed] article", text: "flagged post")
    end

    test "shows posts flagged by another user (as mod)", %{user: user, other_user: other_user} do
      {post, flag} = Fake.create_test_content(:flagged_content, user, other_user)

      conn(user: fake_admin!())
      |> visit("/settings/instance/flags")
      |> assert_has("[data-id=feed] article", text: "flagged post")
    end
  end

  describe "feed sorting" do
    test "sorts posts by interactions", %{user: user, other_user: other_user} do
      # Create posts with different interaction counts
      popular_post =
        fake_post!(other_user, "public", %{
          post_content: %{name: "default post", html_body: "content"}
        })

      less_popular_post =
        fake_post!(other_user, "public", %{
          post_content: %{name: "default post", html_body: "content"}
        })

      # Add likes to make one post more popular
      Enum.each(1..5, fn _ ->
        liker = fake_user!()
        {:ok, _} = Bonfire.Social.Likes.like(liker, popular_post)
      end)

      conn(user: user)
      |> visit("/feed/local")
      |> within("#order-dropdown", fn session ->
        session
        |> click_link("Most liked")
      end)

      # Verify the popular post appears first
      |> assert_has("article:first-child", text: popular_post.post_content.html_body)
    end
  end

  describe "applying feed filters:" do
    # because of async feed (re)loading?
    test "filters out boosts when disabled", %{user: user, other_user: other_user} do
      # Create original post and boost it
      original_post =
        fake_post!(other_user, "public", %{
          post_content: %{name: "default post", html_body: "content"}
        })

      booster = fake_user!("booster")
      {:ok, boost} = Bonfire.Social.Boosts.boost(booster, original_post)

      session =
        conn(user: user)
        |> visit("/feed/explore")
        |> assert_has_or_open_browser("[data-id=feed] article[data-verb=Boost]")
        # |> assert_has("[data-id=feed] article", count: 2)  # Original + boost - TODO: test this way with show_objects_only_once: false filter
        # |> click_button("Filters")
        |> click_button("[data-toggle='boost'] button", "Hide")
        |> wait_async()
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-toggle='boost'] [data-id='disabled'].active")
        |> refute_has("[data-id=feed] article[data-verb=Boost]")
        # Only original
        |> assert_has("[data-id=feed] article", count: 1)
        |> click_button("[data-toggle='boost'] button", "Only")
        |> assert_has("[data-id=feed] article[data-verb=Boost]")
    end
  end
end
