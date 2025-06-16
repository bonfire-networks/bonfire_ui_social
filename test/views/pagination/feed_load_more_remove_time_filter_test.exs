defmodule Bonfire.UI.Social.Feeds.LoadMoreRemoveTimeFilterTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  import Bonfire.Common.Simulation
  use Bonfire.Common.Config
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  use Mneme
  import Untangle
  alias Bonfire.Common.DatesTimes

  describe "Load All Time Buttons in Feeds" do
    setup do
      # Save the original config
      original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])

      # Set the test configuration (disabling deferred joins because they affect pagination)
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)
      # Process.put([:bonfire, :default_pagination_limit], limit)

      # Make sure we start with a blank slate
      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      # Create test users
      account = fake_account!()
      alice = fake_user!(account)

      # Create posts with specific dates
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
      total_posts = 6

      ## Create posts with systematically varied dates for all tests

      # Today's post
      today_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "today's post",
            html_body: "<p>Today's post content</p>"
          },
          id: DatesTimes.now() |> DatesTimes.generate_ulid()
        })

      # Yesterday's post
      two_days_ago_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "2 days ago post",
            html_body: "<p>Yesterday's content</p>"
          },
          id: DatesTimes.past(2, :day) |> DatesTimes.generate_ulid()
        })

      # Three days ago post
      three_days_ago_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "3 days ago post",
            html_body: "<p>Three days ago content</p>"
          },
          id: DatesTimes.past(3, :day) |> DatesTimes.generate_ulid()
        })

      # Week old post
      week_old_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "Week old post",
            html_body: "<p>Week-old content</p>"
          },
          id: DatesTimes.past(7, :day) |> DatesTimes.generate_ulid()
        })

      # Month old post
      month_old_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "Month old post",
            html_body: "<p>Month-old content</p>"
          },
          id: DatesTimes.past(30, :day) |> DatesTimes.generate_ulid()
        })

      # Old post (60 days ago)
      old_post =
        fake_post!(alice, "public", %{
          post_content: %{
            summary: "Old post",
            html_body: "<p>Post from 60 days ago</p>"
          },
          id: DatesTimes.past(60, :day) |> DatesTimes.generate_ulid()
        })

      # Return the original config to be used in on_exit
      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_config)
      end)

      # Return context for tests
      %{
        alice: alice,
        account: account,
        today_post: today_post,
        two_days_ago_post: two_days_ago_post,
        three_days_ago_post: three_days_ago_post,
        week_old_post: week_old_post,
        month_old_post: month_old_post,
        old_post: old_post,
        total_posts: total_posts,
        limit: limit
      }
    end

    test "As a logged-in user, when I click the load_all_time button with date sorting, it should remove time limit and load more activities",
         %{alice: alice, account: account, total_posts: total_posts, limit: limit} do
      conn = conn(user: alice, account: account)

      # Visit feed and set time limit to 1 day using the UI control
      conn
      |> visit("/feed/local")
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]")
      # 0 = Day
      |> fill_in("Time limit control", with: "0")
      |> wait_async()
      # Check that we only see posts from today (count should be less than total)
      # Today's post
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]", count: 1)

      # Test clicking the "load_all_time" button (which continues pagination with no time limit)
      |> assert_has_or_open_browser("[data-id=load_more]")
      |> assert_has_or_open_browser("[data-id=load_more]", text: "Show older activities")
      |> click_button("[data-id=load_more]", "Show older activities")
      |> wait_async()
      # Now we should see more posts beyond the time limit
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]",
        count: 1 + limit
      )

      # Load more again
      |> assert_has_or_open_browser("[data-id=load_more]")
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()

      # Load more again to get all posts
      |> assert_has_or_open_browser("[data-id=load_more]")
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()

      # Now we should see all posts
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]",
        count: total_posts
      )
    end

    test "As a logged-in user, when I click the load_all_time button with non-date sorting, it should reload the feed with no time limit",
         %{alice: alice, account: account, total_posts: total_posts, limit: limit} do
      conn = conn(user: alice, account: account)

      # Visit feed and set time limit to 1 day and sort by likes using UI controls
      conn
      |> visit("/feed/local")
      |> assert_has_or_open_browser("[data-id=feed] article")
      # 0 = Day
      |> fill_in("Time limit control", with: "0")
      |> wait_async()
      # Set sort to likes
      |> within("#order-dropdown", fn session ->
        session
        |> click_link("Most liked")
      end)
      |> wait_async()
      # Check that we only see posts from today (count should be less than total)
      # Today's post
      |> assert_has("[data-id=feed] article [data-id=object_body]", count: 1)

      # Test clicking the "load_all_time" button (which reloads the feed with no time limit)
      |> assert_has_or_open_browser("[data-id=load_all_time]")
      |> click_button("[data-id=load_all_time]", "Show all activities (with no time limit)")
      |> wait_async()
      # Now we should see more posts beyond the time limit
      |> assert_has("[data-id=feed] article [data-id=object_body]", count: limit)

      # Load more to get all posts
      |> assert_has_or_open_browser("[data-id=load_more]")
      |> assert_has_or_open_browser("[data-id=load_more]", text: "Load more")
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Continue loading more
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # Now we should see all posts
      |> assert_has("[data-id=feed] article [data-id=object_body]", count: total_posts)
    end

    test "As a guest user with no socket, I can use the load_all_time link to remove time limits",
         %{total_posts: total_posts, limit: limit} do
      # Use a guest connection (no user)
      conn = conn()

      # Visit feed with a time_limit of 1 day
      conn
      |> visit("/feed/?time_limit=1")
      # Check that we only see posts from today
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]", count: 1)
      # Cannot use "seconds ago" in test as depends on the time of the test run can change to "now", but this is not meaningful for the test.
      # |> PhoenixTest.open_browser()
      # |> assert_has_or("[data-id=feed] article", [text: "seconds ago"], fn session ->
      #   session
      #   |> assert_has("[data-id=feed] article", text: "second ago")
      # end)

      # FIXME: body not preloaded in test env as guest

      # Test clicking the "load_all_time" link (for guests without socket connection)
      |> assert_has_or_open_browser("[data-id=load_all_time]")
      |> click_link("[data-id=load_all_time]", "Show older activities")
      |> wait_async()
      # Now we should see posts without time limit, but still paginated
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit)
      |> assert_has_or_open_browser("[data-id=feed] article", text: "days ago")

      # Load more using the next page links (since this is a no-socket scenario)
      |> click_link("a[data-id=next_page]", "Next page")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit)
      |> assert_has_or_open_browser("[data-id=feed] article", text: "last week")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "4 weeks ago")

      # Continue pagination to see all posts
      |> click_link("a[data-id=next_page]", "Next page")
      |> wait_async()
      # |> assert_has_or_open_browser("[data-id=feed] article", count: limit)
      |> assert_has_or_open_browser("[data-id=feed] article", text: "months ago")
    end
  end
end
