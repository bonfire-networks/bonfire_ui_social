defmodule Bonfire.UI.Social.Threads.PaginationOptimisationsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    Follows.follow(bob, alice)

    {:ok, op} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "<p>OP</p>"}},
        boundary: "public"
      )

    conn = conn(user: bob, account: account2)

    on_exit(fn ->
      Process.put([:bonfire, :thread_pagination_hard_limit], nil)
      Process.put([:bonfire, :thread_default_root_reply_limit], nil)
      Process.put([:bonfire, :pagination_hard_max_limit], nil)
    end)

    {:ok, conn: conn, alice: alice, bob: bob, op: op}
  end

  defp publish_reply(user, reply_to_id, n \\ 1) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{
          post_content: %{html_body: "<p>reply #{n}</p>"},
          reply_to_id: reply_to_id
        },
        boundary: "public"
      )

    post
  end

  describe "small-thread caching (skip two-step on second visit)" do
    test "short thread loads all replies on both first and second visit", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      # set hard limit high so these 3 replies are "small"
      Process.put([:bonfire, :thread_pagination_hard_limit], 20)

      for n <- 1..3, do: publish_reply(alice, op.id, n)

      cache_key = "thread_small:#{op.id}"
      refute Bonfire.Common.Cache.get!(cache_key) == true

      # first visit — unknown count, goes two-step, no next page → caches as small
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']", count: 3)

      assert Bonfire.Common.Cache.get!(cache_key) == true

      # second visit — cached_small=true, uses single query
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']", count: 3)
    end

    test "large thread still shows load-more on first visit", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      # set a low hard limit so these replies are "large"
      Process.put([:bonfire, :thread_pagination_hard_limit], 2)
      Process.put([:bonfire, :thread_default_root_reply_limit], 2)

      for n <- 1..4, do: publish_reply(alice, op.id, n)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id=load_more]")
      |> assert_has("[data-id='comment']", count: 2)
    end
  end

  describe "arrange cap (subtree capping)" do
    test "renders thread when total descendants exceed cap without crashing", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      # cap at 3 total nodes across the arranged tree
      Process.put([:bonfire, :pagination_hard_max_limit], 3)

      # create 2 root replies each with 2 children (6 total nodes)
      r1 = publish_reply(alice, op.id, 1)
      r2 = publish_reply(alice, op.id, 2)
      publish_reply(alice, r1.id, 3)
      publish_reply(alice, r1.id, 4)
      publish_reply(alice, r2.id, 5)
      publish_reply(alice, r2.id, 6)

      # should render without error; cap keeps total ≤ pagination_hard_max_limit
      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id='comment']")
      |> refute_has("[data-role=error]")
    end

    test "load more shows additional subtrees after cap drops some", %{
      conn: conn,
      alice: alice,
      op: op
    } do
      Process.put([:bonfire, :thread_pagination_hard_limit], 20)
      # root limit of 1 means first page has 1 root reply + its subtree
      Process.put([:bonfire, :thread_default_root_reply_limit], 1)

      r1 = publish_reply(alice, op.id, 1)
      publish_reply(alice, r1.id, 2)
      publish_reply(alice, op.id, 3)

      conn
      |> visit("/discussion/#{op.id}")
      |> assert_has("[data-id=load_more]")
      |> click_button("[data-id=load_more]", "Load more")
      |> assert_has("[data-id='comment']", count: 3)
    end
  end
end
