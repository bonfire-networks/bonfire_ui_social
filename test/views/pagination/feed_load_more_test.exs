defmodule Bonfire.UI.Social.Feeds.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: true
  import Bonfire.Common.Simulation
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  use Mneme
  import Untangle

  describe "Load More in Feeds" do
    test "As a user I dont want to see the load more button if there are the same number of activities as the pagination limit" do
      # make sure we start with a blank slate:
      Bonfire.Common.Repo.delete_all(Bonfire.Data.Social.FeedPublish)
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) |> debug("TOTAL POST")
      account = fake_account!()
      me = fake_user!(account)

      # When I login
      conn = conn(user: me, account: account)
      html_body = "epic html message"
      # And I create posts with a 'public' boundary
      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      end

      conn
      |> visit("/feed/local")
      |> assert_has("[data-role=load_more_button]")
      |> click_button("[data-role=load_more_button]")
      |> refute_has("[data-role=load_more_button]")
    end

    test "As a user I dont want to see the load more button if there are less activities than the pagination limit" do
      # make sure we start with a blank slate:
      Bonfire.Common.Repo.delete_all(Bonfire.Data.Social.FeedPublish)

      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) - 1
      account = fake_account!()
      me = fake_user!(account)

      # When I login
      conn = conn(user: me, account: account)
      html_body = "epic html message"
      # And I create posts with a 'public' boundary
      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        {:ok, _post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      end

      conn
      |> visit("/feed/local")
      |> refute_has("[data-role=load_more_button]")
      |> assert_has("[data-id=feed_activity_list]")
    end

    test "As a user I want to see the load more button if there are more activities than the pagination limit" do
      total_posts = 2 + Bonfire.Common.Config.get(:default_pagination_limit, 2)
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)

      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        assert {:ok, _post} =
                 Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: bob, account: account2)

      conn
      |> visit("/feed/local")
      |> assert_has("[data-role=load_more_button]")
    end

    test "As a user when I click on load more I want to see next activities below the others (using LiveView websocket)" do
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) * 2
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)

      for n <- 0..total_posts do
        assert {:ok, _post} =
                 Posts.publish(
                   current_user: alice,
                   post_attrs: %{
                     post_content: %{
                       summary: "summary",
                       name: "#{n} - test post name",
                       html_body: "<p>epic html message</p>"
                     }
                   },
                   boundary: "public"
                 )
      end

      conn = conn(user: alice, account: account)

      # Test using LiveView WebSocket events
      conn
      |> visit("/feed/local")
      # This will use WebSocket event
      |> click_button("[data-id=load_more]")
      # We can use unwrap to access LiveView-specific functions if needed
      |> unwrap(fn view ->
        # Handle any LiveView specific operations here if needed
        # For example, waiting for pubsub messages
        live_pubsub_wait(view)
        view
      end)
      |> assert_has("[data-id=feed] article", count: total_posts)
      |> assert_has("[data-id=subject]", count: total_posts)
    end

    test "As a user when I click on load more on the local feed I want to see next activities even without JavaScript (using HTTP)" do
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) * 2
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # # Create bob user
      # account2 = fake_account!()
      # bob = fake_user!(account2)
      # # bob follows alice
      # Follows.follow(bob, alice)

      for n <- 1..total_posts do
        assert {:ok, _post} =
                 Posts.publish(current_user: alice, post_attrs: post_attrs(n), boundary: "public")
      end

      conn = conn()

      # First get the initial page to see the load more link
      session =
        conn
        |> visit("/feed/local")

        # Extract the pagination URL (without clicking the button)
        # load_more_href = session
        # |> unwrap(fn view ->
        #   href = Floki.attribute(view, "[data-id=load_more] a", "href") |> List.last()
        #   "/feed/local" <> href
        # end)

        # # Now make a direct HTTP request with the pagination parameters
        # conn
        # |> visit(load_more_href) 
        |> click_link("a[data-id=next-page]", "Next page")
        |> assert_has("[data-id=feed] article",
          count: Bonfire.Common.Config.get(:default_pagination_limit, 2)
        )

      session =
        conn
        |> visit("/")
        |> click_link("a[data-id=next-page]", "Next page")
        |> assert_has("[data-id=feed] article",
          count: Bonfire.Common.Config.get(:default_pagination_limit, 2)
        )
    end
  end
end
