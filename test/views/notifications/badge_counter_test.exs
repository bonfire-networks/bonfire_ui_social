defmodule Bonfire.UI.Social.BadgeCounter.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Graph.Follows

  setup do
    alice = fake_user!("alice")
    bob = fake_user!("bob")

    conn_alice = conn(user: alice, account: alice.account)

    {:ok, %{alice: alice, bob: bob, conn_alice: conn_alice}}
  end

  describe "badge counter caching across navigation" do
    test "shows badge after receiving a notification", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Bob mentions Alice to create a notification
      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "Hey @alice check this out"}},
        boundary: "public"
      )

      # Alice visits a page where the badge counter is rendered
      conn_alice
      |> visit("/conduct")
      |> wait_async()
      |> assert_has("[data-item='notifications']")
      |> assert_has("[data-id='widget_badge']")
      |> refute_has("[data-id='no_badge']")
      |> refute_has("[data-id='no_feed_id']")
      |> assert_has("[data-id='unseen_count']")
      |> assert_has("[id^=unseen_count_]")
    end

    @tag :todo
    test "badge counter increments when new notification arrives in real-time", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice opens a page
      session = visit(conn_alice, "/conduct")

      # Bob mentions Alice — should trigger PubSub increment
      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "Hey @alice look at this"}},
        boundary: "public"
      )

      # The badge indicator should appear with a count via the PubSub increment
      session
      |> wait_async()
      |> assert_has("[data-item='notifications']")
      |> assert_has("[data-id='widget_badge']")
      |> refute_has("[data-id='no_badge']")
      |> refute_has("[data-id='no_feed_id']")
      |> assert_has("[data-id='unseen_count']")
      |> assert_has("[id^=unseen_count_]", timeout: 5000)
    end

    @tag :todo
    test "badge count persists across navigation via PersistentLive cache", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Create a notification for Alice first
      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "Hey @alice notification test"}},
        boundary: "public"
      )

      # Alice visits feed — triggers initial count query (CACHE MISS)
      session =
        conn_alice
        |> visit("/conduct")
        |> wait_async()
        |> assert_has("[data-item='notifications']")
        |> assert_has("[data-id='widget_badge']")
        |> refute_has("[data-id='no_badge']")
        |> refute_has("[data-id='no_feed_id']")
        |> assert_has("[data-id='unseen_count']")
        |> assert_has("[id^=unseen_count_]")

      # Give the async task time to complete and store in PersistentLive
      Process.sleep(1000)

      # Navigate to another page — should use cached count (CACHE HIT)
      session
      |> visit("/dashboard")
      |> wait_async()
      |> assert_has("[data-item='notifications']")
      |> assert_has("[data-id='widget_badge']")
      |> refute_has("[data-id='no_badge']")
      |> refute_has("[data-id='no_feed_id']")
      |> assert_has("[data-id='unseen_count']")
      |> assert_has("[id^=unseen_count_]")
    end
  end
end
