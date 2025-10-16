defmodule Bonfire.UI.Social.FeedsFilterTimeLimit.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  import Bonfire.Files.Simulation
  use Bonfire.Common.Repo
  alias Bonfire.Common.DatesTimes

  setup do
    Process.put([:bonfire, :default_pagination_limit], 15)

    _ = fake_admin!()
    user = fake_user!("test user")
    other_user = fake_user!("other user")

    # Create posts with systematically varied dates for all tests

    # Today's post
    today_post =
      fake_post!(user, "public", %{
        post_content: %{name: "Today post", html_body: "Today's post content"},
        id: DatesTimes.now() |> DatesTimes.generate_ulid()
      })

    # Yesterday's post
    yesterday_post =
      fake_post!(user, "public", %{
        post_content: %{name: "Yesterday post", html_body: "Yesterday's content"},
        id: DatesTimes.past(1, :day) |> DatesTimes.generate_ulid()
      })

    # Three days ago
    three_days_ago_post =
      fake_post!(other_user, "public", %{
        post_content: %{name: "3 days ago post", html_body: "Three days ago content"},
        id: DatesTimes.past(3, :day) |> DatesTimes.generate_ulid()
      })

    # A week ago
    week_ago_post =
      fake_post!(other_user, "public", %{
        post_content: %{name: "Week old post", html_body: "Week-old content"},
        id: DatesTimes.past(7, :day) |> DatesTimes.generate_ulid()
      })

    # 25 days ago (within a month)
    month_post =
      fake_post!(user, "public", %{
        post_content: %{name: "Month post", html_body: "Month-old content"},
        id: DatesTimes.past(25, :day) |> DatesTimes.generate_ulid()
      })

    # 45 days ago
    old_post =
      fake_post!(user, "public", %{
        post_content: %{name: "Old post", html_body: "Post from 60 days ago"},
        id: DatesTimes.past(60, :day) |> DatesTimes.generate_ulid()
      })

    # One year ago
    year_ago_post =
      fake_post!(other_user, "public", %{
        post_content: %{name: "Year old post", html_body: "Year-old content"},
        id: DatesTimes.past(365, :day) |> DatesTimes.generate_ulid()
      })

    # Create tagged posts for hashtag filter tests
    # recent_tagged_post =
    #   fake_post!(other_user, "public", %{
    #     post_content: %{name: "Recent tagged", html_body: "Recent content with #test_tag"},
    #     id: DatesTimes.now() |> DatesTimes.generate_ulid()
    #   })

    # old_tagged_post =
    #   fake_post!(other_user, "public", %{
    #     post_content: %{name: "Old tagged", html_body: "Old content with #test_tag"},
    #     id: DatesTimes.past(45, :day) |> DatesTimes.generate_ulid()
    #   })

    # recent_untagged_post =
    #   fake_post!(other_user, "public", %{
    #     post_content: %{name: "Recent untagged", html_body: "Recent content without tag"},
    #     id: DatesTimes.now() |> DatesTimes.generate_ulid()
    #   })

    {:ok,
     %{
       user: user,
       other_user: other_user,
       today_post: today_post,
       yesterday_post: yesterday_post,
       three_days_ago_post: three_days_ago_post,
       week_ago_post: week_ago_post,
       month_post: month_post,
       old_post: old_post,
       year_ago_post: year_ago_post
       # recent_tagged_post: recent_tagged_post,
       # old_tagged_post: old_tagged_post,
       # recent_untagged_post: recent_untagged_post
     }}
  end

  test "user can set time limit filters", %{
    user: user,
    today_post: today_post,
    old_post: old_post
  } do
    conn(user: user)
    |> visit("/feed")
    # Test each time filter option using the range input

    # Set to "Last Day"
    |> click_link("Last Day")
    |> wait_async()
    # Verify we only see today's post
    |> assert_has_or_open_browser("[data-id=feed] article")
    |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
    |> refute_has_or_open_browser("[data-id=feed] article", text: "Post from 60 days ago")
    |> assert_has("label", text: "Last Day")

    # Set to "Last Month"
    # |> click_button("Last Day")
    |> click_link("Last Month")
    |> wait_async()
    # Verify we see recent posts but not older than 30 days
    |> assert_has_or_open_browser("[data-id=feed] article")
    |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
    |> refute_has_or_open_browser("[data-id=feed] article", text: "Post from 60 days ago")
    |> assert_has("label", text: "Last Month")

    # Set to "All time" to verify we can return to seeing everything
    # |> click_button("Last Month")
    |> click_link("All time")
    |> wait_async()
    # Verify we can see posts from all time periods
    |> assert_has_or_open_browser("[data-id=feed] article")
    |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
    |> assert_has("[data-id=feed] article", text: "Post from 60 days ago")
    |> assert_has("label", text: "All time")
  end

  test "respects time filters", %{
    user: user,
    today_post: today_post,
    month_post: month_post,
    old_post: old_post
  } do
    conn(user: user)
    |> visit("/feed/local")
    # Test with Monthly filter (shows posts from last 30 days)

    # Select Month from dropdown
    |> click_link("Last Month")
    # Should show posts within the month limit
    |> assert_has_or_open_browser("[data-id=feed] article")
    |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
    |> assert_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
    # Should not show posts older than a month
    |> refute_has_or_open_browser("[data-id=feed] article", text: "Post from 60 days ago")

    # |> assert_has("label", text: "Last Month")
  end

  describe "time limit feed filters:" do
    test "applies different time limit filters correctly", %{
      user: user,
      today_post: today_post,
      week_ago_post: week_ago_post,
      month_post: month_post,
      year_ago_post: year_ago_post
    } do
      # Test with Day filter
      conn(user: user)
      |> visit("/feed/local")
      # |> PhoenixTest.open_browser()
      # Select Day from dropdown
      |> click_link("Last Day")
      |> assert_has_or_open_browser("[data-id=feed] article")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Week-old content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Year-old content")
      |> assert_has("label", text: "Last Day")

      # Test with Week filter

      |> click_link("Last Week")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Week-old content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Year-old content")
      |> assert_has("label", text: "Last Week")

      # Test with Month filter

      |> click_link("Last Month")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Week-old content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Year-old content")
      |> assert_has("label", text: "Last Month")

      # Test with Year filter

      |> click_link("Last Year")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Week-old content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Year-old content")
      |> assert_has("label", text: "Last Year")

      # Test with All Time filter (should show everything)

      # Select All time from dropdown

      |> click_link("All time")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Today's post content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Week-old content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Month-old content")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Year-old content")
      |> assert_has("label", text: "All time")
    end

    #  do we want to show time limit on hashtag page?
    @tag :todo
    test "combines time limit with other filters", %{
      user: user,
      recent_tagged_post: recent_tagged_post,
      old_tagged_post: old_tagged_post,
      recent_untagged_post: recent_untagged_post
    } do
      # Apply both time limit and hashtag filters
      conn(user: user)
      |> visit("/hashtag/test_tag")
      # Select Month from dropdown
      |> click_link("Last Month")
      |> wait_async()
      # Should show recent tagged post but not old tagged or untagged posts
      |> assert_has("[data-id=feed] article", text: "Recent content with #test_tag")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Old content with #test_tag")
      |> refute_has_or_open_browser("[data-id=feed] article", text: "Recent content without tag")
      |> assert_has("label", text: "Last Month")
    end
  end
end
