defmodule Bonfire.UI.Social.FeedOrderTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  test "drag hook saves the navbar order and ignores invalid orders" do
    user = fake_user!()
    presets = Bonfire.UI.Social.FeedNavigation.list_presets(current_user: user)
    ids = Enum.map(presets, fn {id, _} -> to_string(id) end)
    order = ["my", "local"] ++ Enum.reject(ids, &(&1 in ["my", "local"]))

    conn(user: user)
    |> visit("/settings/user/feeds")
    |> assert_has("#feed-presets-panel[phx-hook=Draggable]")
    |> refute_has("[phx-click=\"Bonfire.Social.Feeds:preset_nav_move\"]")
    |> assert_has("#feed-preset-my[data-sortable-item] [data-sortable-handler]")
    |> PhoenixTest.unwrap(fn view ->
      Phoenix.LiveViewTest.render_hook(view, "Bonfire.Social.Feeds:preset_nav_reorder", %{"target_order" => order})
    end)
    |> assert_has("#feed-presets-panel > li:first-child#feed-preset-my")
    |> PhoenixTest.unwrap(fn view ->
      Phoenix.LiveViewTest.render_hook(view, "Bonfire.Social.Feeds:preset_nav_reorder", %{"target_order" => ["unknown"]})
    end)
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#feed-tabs li:first-child #feed-tab-my")
    |> assert_has("#feed-tabs li:nth-child(2) #feed-tab-local")
  end
end
