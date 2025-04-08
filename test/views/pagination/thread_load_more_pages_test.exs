defmodule Bonfire.UI.Social.Threads.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  describe "Load More in Threads" do
    setup do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)

      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)

      # bob follows alice
      Follows.follow(bob, alice)

      # Standard post attrs
      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      # Create the original post
      {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      reply_attrs = Map.merge(attrs, %{reply_to_id: op.id})

      # Create replies
      total_posts = 4

      for n <- 1..total_posts do
        assert {:ok, _post} =
                 Posts.publish(
                   current_user: alice,
                   post_attrs: post_attrs(n, reply_attrs),
                   boundary: "public"
                 )
      end

      conn = conn(user: bob, account: account2)

      # limit = Config.get(:pagination_hard_max_limit, 10)

      {:ok,
       conn: conn,
       alice: alice,
       bob: bob,
       op: op,
       reply_attrs: reply_attrs,
       total_posts: total_posts}
    end

    test "As a user I don't want to see the load more button if there are less replies than the limit",
         %{conn: conn, alice: alice, op: op, reply_attrs: attrs, total_posts: total_posts} do
      limit = total_posts + 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      # Visit the discussion page
      conn
      |> visit("/discussion/#{op.id}")
      |> refute_has("[data-id=load_more]")
      |> assert_has("[data-id='comment']", count: total_posts)

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      conn
      |> visit("/discussion/#{op.id}")
      |> refute_has("[data-id=load_more]")
      |> assert_has("[data-id='comment']", count: total_posts)
    end

    test "As a user I want to see the load more button if there are more replies", %{
      conn: conn,
      alice: alice,
      op: op,
      reply_attrs: attrs,
      total_posts: total_posts
    } do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      # Visit the discussion page and check for load more button
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id=load_more]")

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id=load_more]")
    end

    test "As a user when I click on load more I want to see next replies below the others (using LiveView websocket)",
         %{conn: conn, alice: alice, op: op, reply_attrs: attrs, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      # Visit the discussion and click the load more button
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']", count: limit)
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-id='comment']", count: 2)

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-role='comment-flat']", count: limit)
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-role='comment-flat']", count: 2)
    end

    test "As a user when I click on load more I want to see next replies even without JavaScript (using HTTP)",
         %{alice: alice, op: op, reply_attrs: attrs, total_posts: total_posts} do
      limit = total_posts - 2

      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      # browse as guest
      conn = conn()

      # Visit the discussion page
      session =
        visit(conn, "/discussion/#{op.id}")
        |> assert_has("[data-id='comment']", count: limit)
        |> assert_has("[data-id=load_more]")
        |> refute_has("[data-role=loading]")
        # |> PhoenixTest.open_browser()
        |> click_link("a[data-id=next_page]", "Next page")
        |> refute_has("[data-role=loading]")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id='comment']", count: 2)
        |> click_link("a[data-id=previous_page]", "Previous page")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id='comment']", count: limit)

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      # Visit the discussion page in flat mode
      session =
        visit(conn, "/discussion/#{op.id}")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-role='comment-flat']", count: limit)
        |> assert_has("[data-id=load_more]")
        |> click_link("a[data-id=next_page]", "Next page")
        |> assert_has("[data-role='comment-flat']", count: 2)
        # |> PhoenixTest.open_browser()
        |> click_link("a[data-id=previous_page]", "Previous page")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-role='comment-flat']", count: limit)
    end
  end
end
