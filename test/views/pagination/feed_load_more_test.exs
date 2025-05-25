defmodule Bonfire.UI.Social.Feeds.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  import Bonfire.Common.Simulation
  use Bonfire.Common.Config
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Messages
  alias Bonfire.Posts
  use Mneme
  import Untangle

  describe "Load more in pages" do
    test "Load more works in followers/following page" do
      Bonfire.Common.Config.get(:default_pagination_limit, 2)
      #  create alice user
      account = fake_account!()
      alice = fake_user!(account)
      #  create bob user
      bob = fake_user!(account)
      # create charlie user
      charlie = fake_user!()
      #  create dave user
      dave = fake_user!()
      #  create eve user
      eve = fake_user!()
      #  bob follows alice
      Follows.follow(bob, alice)
      #  charlie follows alice
      Follows.follow(charlie, alice)
      #  dave follows alice
      Follows.follow(dave, alice)
      #  eve follows alice
      Follows.follow(eve, alice)

      conn =
        conn(user: alice, account: account)
        |> visit("/@#{alice.character.username}/followers")
        |> assert_has("[data-id=profile_name]", count: 2)
        |> click_button("[data-id=load_more]", "Load more")
        |> assert_has("[data-id=profile_name]", count: 4)
    end

    test "Load more works in Search page" do

    end

    test "Load more works in messages list" do
      Bonfire.Common.Config.get(:default_pagination_limit, 2)


      #  create alice user
      account = fake_account!()
      alice = fake_user!(account)
      #  create bob user
      bob = fake_user!(account)
      #  create charlie user
      charlie = fake_user!()
      #  create dave user
      dave = fake_user!()
      #  create eve user
      eve = fake_user!()

      assert {:ok, message} =
               Messages.send(alice, %{to_circles: [bob.id], post_content: %{html_body: "test DM"}})

      assert {:ok, message} =
               Messages.send(alice, %{
                 to_circles: [charlie.id],
                 post_content: %{html_body: "test DM"}
               })

      assert {:ok, message} =
               Messages.send(alice, %{
                 to_circles: [dave.id],
                 post_content: %{html_body: "test DM"}
               })

      assert {:ok, message} =
               Messages.send(alice, %{to_circles: [eve.id], post_content: %{html_body: "test DM"}})

      conn =
        conn(user: alice, account: account)
        |> visit("/messages")
        |> assert_has("[data-id=thread_participants]", count: 2)
        # |> PhoenixTest.open_browser()
        |> click_button("[data-id=load_more]", "Load more")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id=thread_participants]", count: 4)
    end
  end

  describe "Load More in Feeds" do
    setup do
      # Save the original config
      original_config = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])

      # Set the test configuration (disabling deferred joins because they affect pagination)
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)

      # Return the original config to be used in on_exit
      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_config)
      end)

      :ok
    end

    test "As a user, I don't want to see the load more button if there are the same number of activities as the pagination limit" do
      # make sure we start with a blank slate:
      repo().delete_all(Bonfire.Data.Social.FeedPublish)
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
      |> refute_has_or_open_browser("[data-id=load_more]", text: "Load more")
      |> assert_has("[data-id=feed_activity_list]")

      # |> assert_has("[data-id=load_more]")
      # |> click_button("[data-id=load_more]", "Load more")
      # |> refute_has("[data-id=load_more]")
    end

    test "As a user, I don't want to see the load more button if there are less activities than the pagination limit" do
      # make sure we start with a blank slate:
      repo().delete_all(Bonfire.Data.Social.FeedPublish)

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
      |> refute_has_or_open_browser("[data-id=load_more]", text: "Load more")
      |> assert_has("[data-id=feed_activity_list]")
    end

    test "As a logged-in user, when I click on load more I want to see next activities below the others (using LiveView websocket)" do
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
      total_posts = limit * 2
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
      # |> PhoenixTest.open_browser()
      |> assert_has_or_open_browser("[data-id=feed] article", count: limit)
      # This will use WebSocket event
      |> click_button("[data-id=load_more]", "Load more")
      |> wait_async()
      # |> PhoenixTest.open_browser()
      |> assert_has("[data-id=feed] article", count: total_posts)
      |> assert_has("[data-role=subject]", count: total_posts)

      # Then visit the user profile who authored those posts
      conn
      |> visit("/@#{alice.character.username}")
      |> assert_has("[data-id=feed] article",
        count: limit
      )
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-id=feed] article",
        count: total_posts
      )
    end

    test "As a guest, when I click on load more on the local feed I want to see next activities even without JavaScript (using HTTP)" do
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)
      total_posts = limit * 4
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

      # First visit the guest view of the local feed
      # get the initial page to see the load more link
      conn
      |> visit("/feed/local")
      |> assert_has_or_open_browser("[data-id=feed] article",
        count: limit
      )
      # Extract the pagination URL (without clicking the button)
      # load_more_href = session
      # |> unwrap(fn view ->
      #   href = Floki.attribute(view, "[data-id=load_more] a", "href") |> List.last()
      #   "/feed/local" <> href
      # end)

      # # Now make a direct HTTP request with the pagination parameters
      # conn
      # |> visit(load_more_href)
      # |> PhoenixTest.open_browser()
      |> click_link("a[data-id=next_page]", "Next page")
      |> assert_has_or_open_browser("[data-id=feed] article",
        count: limit
      )

      # Then visit the user profile who authored those posts
      conn
      |> visit("/@#{alice.character.username}")
      |> assert_has("[data-id=feed] article",
        count: limit
      )
      |> click_link("a[data-id=next_page]", "Next page")
      |> assert_has("[data-id=feed] article",
        count: limit
      )

      # Then visit the homepage which usually contains the local feed too
      conn
      |> visit("/")
      |> assert_has("[data-id=feed] article",
        count: limit
      )
      |> click_link("a[data-id=next_page]", "Next page")
      |> assert_has("[data-id=feed] article",
        count: limit
      )
    end
  end
end
