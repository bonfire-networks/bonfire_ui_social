defmodule Bonfire.Social.Feeds.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  use Mneme
  import Untangle

  describe "Load More in Feeds" do
    # FIXME: because of deferred joins and infinite scroll we do now show the button - should instead test if once the button is clicked and there's no more activities it disappears
    test "As a user I dont want to see the load more button if there are the same number of activities as the pagination limit" do
      # make sure we start with a blank slate:
      Bonfire.Common.Repo.delete_all(Bonfire.Data.Social.FeedPublish)
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) |> debug("TOTAL POST")
      account = fake_account!()
      me = fake_user!(account)

      # When I login
      conn = conn(user: me, account: account)
      html_body = "epic html message"
      # And I create a post with a 'public' boundary
      attrs = %{post_content: %{html_body: html_body}}

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      end

      {:ok, view, _html} = live(conn, "/feed/local")

      # live_pubsub_wait(view)

      assert has_element?(view, "[data-role=load_more_button]")

      view
      |> element("[data-role=load_more_button]")
      |> render_click()

      refute has_element?(view, "[data-role=load_more_button]")
    end

    # FIXME: because of deferred joins and infinite scroll we do now show the button - should instead test if once the button is clicked and there's no more activities it disappears
    test "As a user I dont want to see the load more button if there are less activities than the pagination limit" do
      # make sure we start with a blank slate:
      Bonfire.Common.Repo.delete_all(Bonfire.Data.Social.FeedPublish)

      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) - 1
      account = fake_account!()
      me = fake_user!(account)

      # When I login
      conn = conn(user: me, account: account)
      html_body = "epic html message"
      # And I create a post with a 'public' boundary
      attrs = %{post_content: %{html_body: html_body}}

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      end

      {:ok, view, _html} = live(conn, "/feed/local")

      refute has_element?(view, "[data-role=load_more_button]")
      feed = element(view, "[data-id=feed_activity_list]")
      assert has_element?(feed)
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
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      {:ok, view, _html} = live(conn, "/feed/local")

      assert has_element?(view, "[data-role=load_more_button]")
    end

    test "As a user when I click on load more I want to see next activities below the others (using LiveView websocket)" do
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) * 2
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)

      # Create bob user
      # account2 = fake_account!()
      # bob = fake_user!(account2)
      # bob follows alice
      # Follows.follow(bob, alice)

      for n <- 0..total_posts do
        assert {:ok, post} =
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
      {:ok, view, html} = live(conn, "/feed/local")

      more_doc =
        view
        |> element("[data-id=load_more]")
        |> render_click()

      # are extra activities being broadcast via pubsub? if so, wait for them
      live_pubsub_wait(view)

      # open_browser(view)
      # articles = Floki.find(more_doc, "[data-id=feed] article")

      articles = element(more_doc, "[data-id=feed] article")
      # # |> debug("articles")

      assert Enum.count(articles) == total_posts
    end

    test "As a user when I click on load more on the local feed I want to see next activities even without JavaScript (using HTTP)" do
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) * 2
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: post_attrs(n), boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      next = "/feed/local"
      {view, doc} = floki_live(conn, next)
      assert [_, load_more_query_string] = Floki.attribute(doc, "[data-id=load_more] a", "href")

      url = "/feed/local" <> load_more_query_string
      info(url, "pagination URL")
      conn = get(conn, url)
      # |> IO.inspect
      more_doc = floki_response(conn)
      entries = Floki.find(more_doc, "[data-id=feed] article")
      # dump(entries, "entries")
      assert Enum.count(entries) == Bonfire.Common.Config.get(:default_pagination_limit, 2)
    end

    test "As a user when I click on load more on the homepage I want to see next activities even without JavaScript (using HTTP)" do
      total_posts = Bonfire.Common.Config.get(:default_pagination_limit, 2) * 2
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: post_attrs(n), boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      next = "/"
      {view, doc} = floki_live(conn, next)
      assert [_, load_more_query_string] = Floki.attribute(doc, "[data-id=load_more] a", "href")

      url = "/" <> load_more_query_string
      info(url, "pagination URL")
      conn = get(conn, url)
      # |> IO.inspect
      more_doc = floki_response(conn)
      entries = Floki.find(more_doc, "[data-id=feed] article")
      # dump(entries, "entries")
      assert Enum.count(entries) == Bonfire.Common.Config.get(:default_pagination_limit, 2)
    end
  end
end
