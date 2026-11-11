defmodule Bonfire.UI.Social.FeedOrderRecoveryTest do
  @moduledoc """
  The feed's Sort form is left out of LiveView's form recovery: replaying it after a reconnect reloads the feed even for an unchanged order, throwing the reader away from their post. Recovery itself runs in the browser JS, so this checks the rendered opt-out.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  test "the Sort form opts out of form recovery" do
    account = fake_account!()
    me = fake_user!(account)

    conn(user: me, account: account)
    |> visit(Bonfire.UI.Social.FeedNavigation.build_path(:explore))
    |> wait_async()
    |> assert_has(
      "form[data-role=feed_order_row][phx-change=set_feed_order][phx-auto-recover=ignore]"
    )
  end
end
