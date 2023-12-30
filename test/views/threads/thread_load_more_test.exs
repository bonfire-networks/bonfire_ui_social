defmodule Bonfire.Social.Threads.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  describe "Load More in Threads" do
    test "As a user I dont want to see the load more button if there are less than 11 replies" do
      total_posts = 10
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

      assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      attrs = Map.merge(attrs, %{reply_to_id: op.id})

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      next = "/discussion/#{op.id}"
      {:ok, view, _html} = live(conn, next)
      live_pubsub_wait(view)

      open_browser(view)
      # {view, doc} = floki_live(conn, next)
      assert Floki.find(view, "[data-id=load_more]") == []
      # |> debug()
      replies = Floki.find(view, "[data-id='replies'] > [data-id='comment']")
      assert Enum.count(replies) == total_posts
    end

    test "As a user I want to see the load more button if there are more than 11 replies" do
      total_posts = 11
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

      assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      attrs = Map.merge(attrs, %{reply_to_id: op.id})

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      next = "/discussion/#{op.id}"
      {view, doc} = floki_live(conn, next)
      assert Floki.find(doc, "[data-id=load_more]") != []
    end

    @tag :skip_ci
    test "As a user when I click on load more I want to see next replies below the others (using LiveView websocket)" do
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

      assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      attrs = Map.merge(attrs, %{reply_to_id: op.id})

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      end

      conn = conn(user: bob, account: account2)
      next = "/discussion/#{op.id}"
      {view, doc} = floki_live(conn, next)
      # assert {:ok, more_doc} = Floki.parse_document(render(view))
      more_doc =
        view
        |> element("[data-id=load_more]")
        |> render_click()

      # |> debug()

      # |> debug()
      replies = Floki.find(more_doc, "[data-id='replies'] > [data-id='comment']")
      assert Enum.count(replies) == total_posts
    end

    test "As a user when I click on load more I want to see next replies even without JavaScript (using HTTP)" do
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

      assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      attrs = Map.merge(attrs, %{reply_to_id: op.id})

      for n <- 1..total_posts do
        assert {:ok, post} =
                 Posts.publish(
                   current_user: alice,
                   post_attrs: post_attrs(n, attrs),
                   boundary: "public"
                 )
      end

      conn = conn(user: bob, account: account2)
      next = "/discussion/#{op.id}"
      {view, doc} = floki_live(conn, next)

      # replies = Floki.find(doc, "[data-id='replies'] > [data-id='comment']")
      # |> info("replies")

      assert [_, load_more_query_string] = Floki.attribute(doc, "[data-id=load_more] a", "href")

      url = "/discussion/#{op.id}" <> load_more_query_string
      info(url, "pagination url")

      conn = get(conn, url)
      # |> IO.inspect
      more_doc = floki_response(conn)

      replies = Floki.find(more_doc, "[data-id='replies'] > [data-id='comment']")
      # |> info("replies")
      assert Enum.count(replies) == 5
    end
  end
end
