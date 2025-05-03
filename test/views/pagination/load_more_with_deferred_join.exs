defmodule Bonfire.UI.Social.Feeds.DeferredJoinPaginationTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  import Bonfire.Common.Simulation
  use Bonfire.Common.Config
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  use Mneme
  import Untangle

  describe "Feed Pagination with Deferred Join" do
    setup do
      # Create a user for testing
      account = fake_account!()
      me = fake_user!(account)

      # Save the original config
      original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])

      # Ensure deferred join is enabled for these tests
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], true)

      # Return the original config to be used in on_exit
      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_config)
      end)

      # Return context
      %{
        account: account,
        me: me
      }
    end

    test "works for local feed with window fallback behavior", %{account: account, me: me} do
      # make sure we start with a clean slate:
      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      # Setup test users
      other_user = fake_user!()

      # Configure posts to exceed default pagination limit
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
      total_posts = limit * 2

      # PART 1: Create test data to verify window fallback behavior
      # ------------------------------------------------------------

      # First create posts that would be in a later window
      # These should be found via deferred join window fallback
      for n <- 1..limit do
        assert {:ok, _post} =
                 Posts.publish(
                   current_user: me,
                   boundary: "public",
                   post_attrs: %{
                     post_content: %{
                       html_body: "Old Content #{n}"
                     }
                   }
                 )
      end

      # Create (more recent) posts that would appear in the first window but won't be included by boundaries
      # These should NOT appear in our feed due to boundary restrictions
      for i <- 1..(limit * 8) do
        Posts.publish(
          current_user: other_user,
          boundary: "mentions",
          post_attrs: %{
            post_content: %{
              html_body: "Private Content #{i}"
            }
          }
        )
      end

      # PART 2: Create additional public posts to test pagination with deferred join
      # ------------------------------------------------------------

      # Create additional public posts for pagination testing
      for n <- 1..limit do
        assert {:ok, _post} =
                 Posts.publish(
                   current_user: me,
                   post_attrs: %{
                     post_content: %{
                       html_body: "New Content #{n}"
                     }
                   },
                   boundary: "public"
                 )
      end

      # PART 3: Test window fallback behavior
      # ------------------------------------------------------------

      # Access the feed with deferred join enabled
      conn = conn(user: me, account: account)

      conn
      |> visit("/feed/local")
      |> wait_async()

      # Verify window fallback works correctly:
      # - Should find posts via window fallback even if not in first window
      |> assert_has_or_open_browser("[data-id=feed] article", text: "New Content")
      |> assert_has_count("[data-id=feed] article", count: limit)
      |> refute_has_text("[data-id=feed] article", "Private Content")

      # PART 4: Test pagination with deferred join
      # ------------------------------------------------------------

      # Now test pagination with the posts we created
      # First page should display correctly
      |> assert_has_or_open_browser("[data-id=load_more]")

      # Navigate to second page
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()

      # Verify more posts are displayed (accumulating, no duplicates)
      # Count should increase as more posts are loaded
      |> assert_has_count("[data-id=feed] article", greater_than: limit, less_or_equal: limit * 2)

      # Verify the content
      #   |> PhoenixTest.open_browser()
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Old Content 2")

      # Click load more again
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()

      # Verify we've now loaded even more posts
      #   |> PhoenixTest.open_browser()
      |> assert_has("[data-id=feed] article", text: "New Content 2")
      |> assert_has("[data-id=feed] article", text: "New Content 1")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Old Content 2")
      |> assert_has_or_open_browser("[data-id=feed] article", text: "Old Content 1")
      |> refute_has_text("[data-id=feed] article", "Private Content")
      |> assert_has("[data-id=feed] article", count: total_posts)
    end
  end
end
