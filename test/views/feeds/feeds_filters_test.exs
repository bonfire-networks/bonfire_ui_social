defmodule Bonfire.UI.Social.FeedsFilters.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]

  setup do
    user = fake_user!("test_user")
    other_user = fake_user!("other_user")
    {:ok, %{user: user, other_user: other_user}}
  end

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

    test "user can set time limit filters", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # |> click_button("Filters")
      |> within("[data-scope='time_limit']", fn session ->
        session # TODO refactor to use range
        |> choose("All time")
        |> choose("Day")
        |> choose("Week")
        |> choose("Month")
        |> choose("Year")
      end)
    end

    # if this is desired?
    @tag :todo
    test "filters persist after navigation", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # |> click_button("Filters")
      # Set some filters
      |> within("[data-scope='time_limit']", fn session ->
        session
        |> choose("Day")
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
      {post, _} = create_test_content(:my, user, other_user)

      conn(user: user)
      |> visit("/feed/my")
      |> assert_has("[data-id=feed] article", text: "content from someone I follow")
      |> assert_has("[data-id=feed] article", text: other_user.character.username)
    end
  end

  describe "bookmarks feed" do
    test "shows bookmarked posts", %{user: user, other_user: other_user} do
      {post, _} = create_test_content(:my_bookmarks, user, other_user)

      conn(user: user)
      |> visit("/feed/my/bookmarks")
      |> assert_has("[data-id=feed] article", text: "bookmarkable post")
    end
  end

  describe "mentions feed" do
    test "shows posts mentioning the user", %{user: user, other_user: other_user} do
      {post, _} = create_test_content(:mentions, user, other_user)

      conn(user: user)
      |> visit("/feed/mentions")
      |> assert_has("[data-id=feed] article", text: "@#{user.character.username}")
    end
  end

  describe "hashtag feed" do
    test "shows posts with specific hashtags", %{user: user, other_user: other_user} do
      {post, _} = create_test_content(:hashtag, user, other_user)

      conn(user: user)
      |> visit("/feed/hashtag/test")
      |> assert_has("[data-id=feed] article", text: "#test")
    end
  end

  describe "local feed" do
    test "shows local posts", %{user: user, other_user: other_user} do
      {post, _} = create_test_content(:local, user, other_user)

      conn(user: user)
      |> visit("/feed/local")
      |> assert_has("[data-id=feed] article", text: "default post")
    end

    @tag :todo
    test "respects time filters", %{user: user, other_user: other_user} do
      # Create an old post
      old_time = DateTime.add(DateTime.utc_now(), -60, :day)

      old_post =
        fake_post!(other_user, "public", %{
          post_content: %{name: "default post", html_body: "content"}
        })

      # Update post timestamp to be old
      Repo.update_all("posts", set: [inserted_at: old_time])

      # Create a new post
      new_post =
        fake_post!(other_user, "public", %{
          post_content: %{name: "default post", html_body: "content"}
        })

      conn(user: user)
      |> visit("/feed/local")
      # |> click_button("Filters")
      |> within("[data-scope='time_limit']", fn session ->
        session
        |> choose("Month")
      end)
      |> assert_has("[data-id=feed] article", text: "default post")
      |> refute_has("[data-id=feed] article", text: old_post.post_content.html_body)
    end
  end

  describe "liked content feed" do
    test "shows posts liked by user", %{user: user, other_user: other_user} do
      {post, like} = create_test_content(:liked_by_me, user, other_user)

      conn(user: user)
      |> visit("/feed/liked")
      |> assert_has("[data-id=feed] article", text: "likeable post")
    end
  end

  describe "flagged content feed" do
    test "shows posts flagged by me", %{user: user, other_user: other_user} do
      {post, flag} = create_test_content(:flagged_by_me, user, other_user)

      conn(user: user)
      |> visit("/settings/user/flags")
      |> assert_has("[data-id=feed] article", text: "flagged post")
    end

    test "shows posts flagged by another user (as mod)", %{user: user, other_user: other_user} do
      {post, flag} = create_test_content(:flagged_content, user, other_user)

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
        |> visit("/feed/local")
        |> assert_has("[data-id=feed] article[data-verb=Boost]")
        # |> assert_has("[data-id=feed] article", count: 2)  # Original + boost - TODO: test this way with show_objects_only_once: false filter
        # |> click_button("Filters")
        |> click_button("[data-toggle='boost'] button", "Hide")

      live_async_wait(session) # FIXME?

      session
      |> refute_has("[data-id=feed] article[data-verb=Boost]")
      # |> assert_has("[data-id=feed] article", count: 1)  # Only original
      |> click_button("[data-toggle='boost'] button", "Only")
      |> assert_has("[data-id=feed] article[data-verb=Boost]")
    end
  end

  # Helper to create appropriate test content based on feed type
  defp create_test_content(preset, user, other_user) do
    case preset do
      :my ->
        other_user = fake_user!("other_user")

        assert {:ok, %Bonfire.Data.Social.Follow{} = follow} =
                 Bonfire.Social.Graph.Follows.follow(user, other_user)

        # assert {:ok, %Bonfire.Data.Social.Follow{} = follow} =
        #          Bonfire.Social.Graph.Follows.follow(other_user, user)

        assert post =
                 fake_post!(other_user, "public", %{
                   post_content: %{
                     name: "followed user post",
                     html_body: "content from someone I follow"
                   }
                 })

        # FIXME: why is post not appearing in my feed?
        {post, nil}

      :remote ->
        #   remote_user = fake_remote_user!("remote_user")

        #   post =
        #     fake_post!(remote_user, "public", %{
        #       post_content: %{
        #         name: "remote post",
        #         html_body: "content from fediverse"
        #       }
        #     })

        # TODO
        {nil, nil}

      :notifications ->
        create_test_content(:mentions, user, other_user)

      :liked_by_me ->
        assert post =
                 fake_post!(other_user, "public", %{
                   post_content: %{name: "likeable post", html_body: "content"}
                 })

        assert {:ok, like} = Bonfire.Social.Likes.like(user, post)
        {post, like}

      :user_followers ->
        assert {:ok, follow} = Bonfire.Social.Graph.Follows.follow(user, other_user)

        {other_user, follow}

      :user_following ->
        assert {:ok, follow} = Bonfire.Social.Graph.Follows.follow(other_user, user)

        {user, follow}

      :my_requests ->
        # TODO
        {nil, nil}

      :my_bookmarks ->
        assert post =
                 fake_post!(user, "public", %{
                   post_content: %{name: "bookmarkable post", html_body: "content"}
                 })

        assert {:ok, bookmark} = Bonfire.Social.Bookmarks.bookmark(user, post)

        {post, nil}

      :hashtag ->
        assert post =
                 fake_post!(user, "public", %{
                   post_content: %{name: "tagged post", html_body: "post with #test"}
                 })

        {post, nil}

      :mentions ->
        assert post =
                 fake_post!(other_user, "public", %{
                   post_content: %{name: "mention me", html_body: "@#{user.character.username}"}
                 })

        {post, nil}

      :flagged_by_me ->
        assert post =
                 fake_post!(other_user, "public", %{
                   post_content: %{name: "flagged post", html_body: "content"}
                 })

        assert {:ok, flag} = Bonfire.Social.Flags.flag(user, post)
        {post, flag}

      :flagged_content ->
        assert post =
                 fake_post!(fake_user!(), "mentions", %{
                   post_content: %{name: "flagged post", html_body: "content"}
                 })

        assert {:ok, flag} = Bonfire.Social.Flags.flag(other_user, post)
        {post, flag}

      :local_images ->
        # assert {:ok, media} = Bonfire.Files.upload(ImageUploader, user, icon_file())
        # post =
        #   fake_post!(user, "public", %{
        #     post_content: %{name: "media post", html_body: "content"},
        #     uploaded_media: [media]
        #   })
        # {media, nil}

        # TODO: images or open science publications attached to a post aren't directly linked to an activity (as opposed to open science publications fetched from ORCID API) so not included in current feed query, so need to adapt the feed query...
        {nil, nil}

      :research ->
        #   assert {:ok, media} = Bonfire.OpenScience.APIs.fetch_and_publish_work(user, "https://doi.org/10.1080/1047840X.2012.720832")
        #   {media, nil} 

        #  FIXME: feed ends up empty
        {nil, nil}

      :local_media ->
        # TODO: with both image and publication?
        {nil, nil}

      :trending_discussions ->
        # TODO
        {nil, nil}

      :messages ->
        #   receiver = Fake.fake_user!()
        #   attrs = %{
        #     to_circles: [receiver.id],
        #     post_content: %{name: "test DM", html_body: "content"}
        #   }
        #   assert {:ok, message} = Messages.send(user, attrs)
        #   {receiver, message}

        # TODO?
        {nil, nil}

      other
      when is_nil(other) or other in [:local, :explore, :user_by_object_type, :user_activities] ->
        assert post =
                 fake_post!(other_user, "public", %{
                   post_content: %{name: "default post", html_body: "content"}
                 })

        {post, nil}

      other ->
        raise "Missing create_test_content case for #{inspect(other)}"
    end
  end
end
