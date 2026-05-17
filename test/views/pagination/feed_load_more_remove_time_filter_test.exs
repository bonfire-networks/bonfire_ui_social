defmodule Bonfire.UI.Social.Feeds.LoadMoreRemoveTimeFilterTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  use Bonfire.Common.Config
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  use Mneme
  alias Bonfire.Common.DatesTimes

  defp dated_post!(user, summary, body, date) do
    fake_post!(user, "public", %{
      post_content: %{
        summary: summary,
        html_body: "<p>#{body}</p>"
      },
      id: DatesTimes.generate_ulid(date)
    })
  end

  describe "Load All Time Buttons in Feeds" do
    setup do
      # Save the original config
      original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])

      # Set the test configuration (disabling deferred joins because they affect pagination)
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)
      # Process.put([:bonfire, :default_pagination_limit], limit)
      Bonfire.Common.Cache.remove_all()

      # Create test users
      account = fake_account!()
      alice = fake_user!(account)
      author = fake_user!()

      # Make sure user/account setup activities do not affect feed counts.
      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      # Create posts with specific dates
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
      total_posts = 6

      ## Create posts with systematically varied dates for all tests

      today_post =
        dated_post!(author, "today's post", "Today's post content", DatesTimes.past(1, :hour))

      two_days_ago_post =
        dated_post!(author, "2 days ago post", "Yesterday's content", DatesTimes.past(2, :day))

      three_days_ago_post =
        dated_post!(author, "3 days ago post", "Three days ago content", DatesTimes.past(3, :day))

      week_old_post =
        dated_post!(author, "Week old post", "Week-old content", DatesTimes.past(7, :day))

      month_old_post =
        dated_post!(author, "Month old post", "Month-old content", DatesTimes.past(30, :day))

      old_post =
        dated_post!(author, "Old post", "Post from 60 days ago", DatesTimes.past(60, :day))

      # Return the original config to be used in on_exit
      on_exit(fn ->
        Bonfire.Common.Cache.remove_all()
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

    @tag :pagination_time_limit
    test "cached local feed pages do not reuse a different time limit", %{
      alice: alice,
      account: account,
      total_posts: total_posts
    } do
      opts = [
        current_user: alice,
        current_account: account,
        cache: true,
        limit: total_posts,
        preload: false,
        query_with_deferred_join: false,
        show_objects_only_once: false
      ]

      limited_feed = Bonfire.Social.FeedLoader.feed(:local, %{time_limit: 1}, opts)
      all_time_feed = Bonfire.Social.FeedLoader.feed(:local, %{time_limit: 0}, opts)

      assert length(limited_feed.edges) == 1
      assert length(all_time_feed.edges) == total_posts
    end

    @tag :pagination_time_limit
    test "As a logged-in user, when I click the load_all_time button with date sorting, it should remove time limit and load more activities",
         %{
           alice: alice,
           account: account,
           total_posts: total_posts,
           limit: limit
         } do
      conn = conn(user: alice, account: account)

      # Fake posts do not exercise the production cache invalidation path, so bypass feed cache.
      conn
      |> visit("/feed/local?cache=skip&time_limit=1")
      |> assert_has_or_open_browser("[data-id=feed] article [data-id=object_body]")
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

    @tag :pagination_time_limit
    test "As a logged-in user, when I click the load_all_time button with non-date sorting, it should reload the feed with no time limit",
         %{alice: alice, account: account, total_posts: total_posts, limit: limit} do
      conn = conn(user: alice, account: account)

      # Fake posts do not exercise the production cache invalidation path, so bypass feed cache.
      conn
      |> visit("/feed/local?cache=skip&time_limit=1&sort_by=like_count&sort_order=desc")
      |> assert_has_or_open_browser("[data-id=feed] article")
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

    @tag :pagination_time_limit
    test "As a guest user with no socket, I can use the load_all_time link to remove time limits",
         %{limit: limit} do
      # Use a guest connection (no user)
      conn = conn()

      # Visit feed with a time_limit of 1 day
      conn
      |> visit("/feed/?cache=skip&time_limit=1")
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
