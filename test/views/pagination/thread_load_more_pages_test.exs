defmodule Bonfire.UI.Social.Threads.LoadMoreTest do
  use Bonfire.UI.Social.ConnCase, async: false
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

      on_exit(fn ->
        Process.put([:bonfire, :default_pagination_limit], nil)
        Process.put([:bonfire, :pagination_hard_max_limit], nil)
      end)

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

      # Visit the discussion   page and check for load more button
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has_or_open_browser("[data-id=load_more]")

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
      |> assert_has("[data-id='comment']", count: total_posts)

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-role='comment-flat']", count: limit)
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-role='comment-flat']", count: total_posts)
    end

    test "Load more inserts replies into the stream, not into a separate manually-assigned list (nested mode)",
         %{conn: conn, op: op, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      conn
      |> visit("/discussion/#{op.id}")
      |> refute_has("[data-role=threaded_replies_assigned] [data-id=comment]")
      |> assert_has("[data-id=comment]", count: limit)
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-id=comment]", count: total_posts)
      |> refute_has("[data-role=threaded_replies_assigned] [data-id=comment]")
      |> assert_has("[phx-update=stream] [data-id=comment]", count: total_posts)
    end

    test "Load more inserts replies into the stream, not into a separate manually-assigned list (flat mode)",
         %{conn: conn, op: op, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)
      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      conn
      |> visit("/discussion/#{op.id}")
      |> refute_has("[data-role=replies_assigned] [data-role='comment-flat']")
      |> assert_has("[data-role='comment-flat']", count: limit)
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-role='comment-flat']", count: total_posts)
      |> refute_has("[data-role=replies_assigned] [data-role='comment-flat']")
      |> assert_has("[phx-update=stream] [data-role='comment-flat']", count: total_posts)
    end

    test "As a user when I click on load more I want to see next replies even without JavaScript (using HTTP)",
         %{alice: alice, op: op, reply_attrs: attrs, total_posts: total_posts} do
      limit = total_posts - 2

      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      # browse as guest
      conn = conn()

      # Visit the discussion page. No-JS guests get a forward-only "Next page" link
      # (there is no "Previous page" in a thread).
      session =
        visit(conn, "/discussion/#{op.id}")
        |> assert_has("[data-id='comment']", count: limit)
        |> assert_has("[data-id=load_more]")
        |> refute_has("[data-role=loading]")
        |> refute_has("a[data-id=previous_page]")
        # |> PhoenixTest.open_browser()
        |> click_link("a[data-id=next_page]", "Next page")
        |> refute_has("[data-role=loading]")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id='comment']", count: 2)

      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)

      # Visit the discussion page in flat mode
      session =
        visit(conn, "/discussion/#{op.id}")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-role='comment-flat']", count: limit)
        |> assert_has("[data-id=load_more]")
        |> refute_has("a[data-id=previous_page]")
        |> click_link("a[data-id=next_page]", "Next page")
        |> assert_has("[data-role='comment-flat']", count: 2)
    end
  end

  describe "Load More in Threads at scale" do
    @total_posts 30
    @page_size 5

    # Trailing `_END` ensures no marker is a substring of another, so PhoenixTest's
    # substring text-match can verify each reply is present exactly once.
    defp marker_for(n), do: "REPLY_#{n}_END"

    setup do
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      Follows.follow(bob, alice)

      attrs = %{
        post_content: %{
          summary: "summary",
          html_body: "<p>epic html message</p>"
        }
      }

      {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      reply_attrs = Map.merge(attrs, %{reply_to_id: op.id})

      for n <- 1..@total_posts do
        named_attrs =
          Map.merge(reply_attrs, %{
            post_content: %{name: marker_for(n), html_body: "<p>body</p>"}
          })

        assert {:ok, _post} =
                 Posts.publish(
                   current_user: alice,
                   post_attrs: named_attrs,
                   boundary: "public"
                 )
      end

      conn = conn(user: bob, account: account2)

      Process.put([:bonfire, :default_pagination_limit], @page_size)
      Process.put([:bonfire, :pagination_hard_max_limit], @page_size)

      on_exit(fn ->
        Process.put([:bonfire, :default_pagination_limit], nil)
        Process.put([:bonfire, :pagination_hard_max_limit], nil)
      end)

      {:ok, conn: conn, op: op}
    end

    test "walking through #{@total_posts} replies via repeated Load more clicks accumulates without loss or duplication (nested mode)",
         %{conn: conn, op: op} do
      total_pages = div(@total_posts, @page_size)

      # Initial: page 1
      session =
        conn
        |> visit("/discussion/#{op.id}")
        |> assert_has("[phx-update=stream] [data-id=comment]", count: @page_size)

      # Click "Load more" page-by-page until all replies are visible.
      session =
        Enum.reduce(2..total_pages, session, fn page, s ->
          s
          |> click_button("button[data-id=load_more]", "Load more")
          |> assert_has("[phx-update=stream] [data-id=comment]", count: page * @page_size)
        end)

      # All #{@total_posts} unique post titles must be present exactly once.
      Enum.each(1..@total_posts, fn n ->
        assert_has(session, "[phx-update=stream] [data-id=comment]",
          text: marker_for(n),
          count: 1
        )
      end)

      # No comment leaked into the manually-assigned (non-stream) block.
      refute_has(session, "[data-role=threaded_replies_assigned] [data-id=comment]")
    end

    test "walking through #{@total_posts} replies via repeated Load more clicks accumulates without loss or duplication (flat mode)",
         %{conn: conn, op: op} do
      Process.put([:bonfire_ui_social, Bonfire.UI.Social.ThreadLive, :thread_mode], :flat)
      total_pages = div(@total_posts, @page_size)

      session =
        conn
        |> visit("/discussion/#{op.id}")
        |> assert_has("[phx-update=stream] [data-role='comment-flat']", count: @page_size)

      session =
        Enum.reduce(2..total_pages, session, fn page, s ->
          s
          |> click_button("button[data-id=load_more]", "Load more")
          |> assert_has("[phx-update=stream] [data-role='comment-flat']",
            count: page * @page_size
          )
        end)

      Enum.each(1..@total_posts, fn n ->
        assert_has(session, "[phx-update=stream] [data-role='comment-flat']",
          text: marker_for(n),
          count: 1
        )
      end)

      refute_has(session, "[data-role=replies_assigned] [data-role='comment-flat']")
    end

    test "after walking the entire thread the Load more button is gone (nested mode)",
         %{conn: conn, op: op} do
      total_pages = div(@total_posts, @page_size)

      session =
        conn
        |> visit("/discussion/#{op.id}")
        |> assert_has("button[data-id=load_more]")

      session =
        Enum.reduce(2..total_pages, session, fn _page, s ->
          click_button(s, "button[data-id=load_more]", "Load more")
        end)

      session
      |> assert_has("[phx-update=stream] [data-id=comment]", count: @total_posts)
      |> refute_has("button[data-id=load_more]")
    end
  end

  describe "Threads never show a 'load previous' control (infinite scroll, forward-only)" do
    setup do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      Follows.follow(bob, alice)

      attrs = %{
        post_content: %{summary: "summary", html_body: "<p>epic html message</p>"}
      }

      {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      reply_attrs = Map.merge(attrs, %{reply_to_id: op.id})

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

      on_exit(fn ->
        Process.put([:bonfire, :default_pagination_limit], nil)
        Process.put([:bonfire, :pagination_hard_max_limit], nil)
      end)

      {:ok, conn: conn, op: op, total_posts: total_posts}
    end

    test "the load more control opts into infinite scrolling (LoadMore hook)",
         %{conn: conn, op: op, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      conn
      |> visit("/discussion/#{op.id}")
      # the button carries the LoadMore JS hook so it auto-loads when scrolled into view
      |> assert_has("button[data-id=load_more][phx-hook=LoadMore]")
    end

    test "no 'load previous' control on a fresh thread visit",
         %{conn: conn, op: op, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("button[data-id=load_more]")
      # `before` cursor = backwards pagination, which must never be rendered in a thread
      |> refute_has("[phx-value-before]")
      |> refute_has("a[data-id=previous_page]")
    end

    test "no 'load previous' control appears even after a forward Load more click (regression)",
         %{conn: conn, op: op, total_posts: total_posts} do
      limit = total_posts - 2
      Process.put([:bonfire, :default_pagination_limit], limit)
      Process.put([:bonfire, :pagination_hard_max_limit], limit)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[phx-update=stream] [data-id=comment]", count: limit)
      |> refute_has("[phx-value-before]")
      |> click_button("button[data-id=load_more]", "Load more")
      |> assert_has("[phx-update=stream] [data-id=comment]", count: total_posts)
      # this is the actual bug: loading more forward used to reveal a "load previous" button
      |> refute_has("[phx-value-before]")
      |> refute_has("a[data-id=previous_page]")
    end
  end
end
