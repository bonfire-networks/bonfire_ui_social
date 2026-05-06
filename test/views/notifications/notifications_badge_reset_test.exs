defmodule Bonfire.UI.Social.NotificationsBadgeResetTest do
  @moduledoc """
  Verifies that visiting `/notifications` automatically marks every
  unseen activity in the receiver's notifications feed as seen — same
  effect as clicking the "Mark all as read" button on the page header.
  """

  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.FeedActivities

  setup do
    alice = fake_user!("alice")
    bob = fake_user!("bob")

    {:ok, _post} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "Hey @alice ping"}},
        boundary: "public"
      )

    conn_alice = conn(user: alice, account: alice.account)
    {:ok, alice: alice, bob: bob, conn_alice: conn_alice}
  end

  test "visiting /notifications clears the notifications unseen count", %{
    alice: alice,
    conn_alice: conn_alice
  } do
    assert FeedActivities.unseen_count(:notifications, current_user: alice) > 0,
           "test premise broken: expected alice to have unseen notifications after the @-mention"

    conn_alice
    |> visit("/notifications")
    |> wait_async()

    assert FeedActivities.unseen_count(:notifications, current_user: alice) == 0,
           "expected /notifications to mark all notification items as seen on visit"
  end

  test "visiting /notifications drops the notifications badge indicator from the rendered DOM",
       %{alice: alice, conn_alice: conn_alice} do
    # Beyond the data-layer assertion above: verify the user-visible badge.
    # The `BadgeCounterLive` component always renders `[data-id=unseen_count]`
    # but only renders an `.indicator-item` div inside when `count > 0`.
    notifications_id = e(alice, :character, :notifications_id, nil)
    refute is_nil(notifications_id), "test premise broken: alice has no notifications_id"

    conn_alice
    |> visit("/notifications")
    |> wait_async()
    |> refute_has(~s|#unseen_count_#{notifications_id} .indicator-item|)
  end
end
