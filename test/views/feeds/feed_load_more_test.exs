defmodule Bonfire.Social.Feeds.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Posts

  import Untangle

  describe "Load More in Feeds" do
    test "As a user I dont want to see the load more button if there are less than 11 activities" do
      total_posts = 10

      account = fake_account!()
      me = fake_user!(account)

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: me, account: account)
      next = "/feed/local"
      {:ok, view, doc} = live(conn, "/feed/local")
      assert has_element?(view, "[data-id=load_more]")
      # option_count = length(list_of_options)
      # assert view |> element("[data-id=feed] article:nth-of-type(#{option_count})") |> has_element?()
      # refute view |> element("[data-id=feed] article:nth-of-type(#{option_count + 1})") |> has_element?()
      # # assert Enum.count(view |> element("[data-id=feed] article")) == total_posts
      assert Floki.find(doc, "[data-id=load_more]") == []
      assert Enum.count(Floki.find(doc, "[data-id=feed] article")) == total_posts
    end

    test "As a user I want to see the load more button if there are more than 11 activities" do
      total_posts = 15
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
      next = "/feed/local"
      {view, doc} = floki_live(conn, next)
      assert Floki.find(doc, "[data-id=load_more]") != []
    end

    test "As a user when I click on load more I want to see next activities below the others (using LiveView websocket)" do
      total_posts = 15
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      # account2 = fake_account!()
      # bob = fake_user!(account2)
      # bob follows alice
      # Follows.follow(bob, alice)

      for n <- 1..total_posts do
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
      next = "/feed/local"
      {view, doc} = floki_live(conn, next)

      articles = Floki.find(doc, "[data-id=feed] article")
      # |> info("articles")

      assert Enum.count(articles) == 10

      more_doc =
        view
        |> element("[data-id=load_more]")
        |> render_click()

      # are extra activities being broadcast via pubsub? if so, wait for them
      live_pubsub_wait(view)

      articles = Floki.find(more_doc, "[data-id=feed] article")

      # |> info("articles")

      assert Enum.count(articles) == 15
    end

    test "As a user when I click on load more I want to see next activities even without JavaScript (using HTTP)" do
      total_posts = 15
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
      assert Enum.count(entries) == 5
    end
  end
end
