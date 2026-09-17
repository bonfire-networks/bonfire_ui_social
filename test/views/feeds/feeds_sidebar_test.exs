defmodule Bonfire.UI.Social.FeedsSidebarTest do
  use Bonfire.UI.Social.ConnCase, async: false

  @moduletag :ui

  test "feeds starts collapsed outside a feed and opens Following from its label" do
    conn(user: fake_user!())
    |> visit("/")
    |> wait_async()
    |> assert_has("#sidebar-feeds-list:not([open])", timeout: 2000)
    |> assert_has("#sidebar-feeds-link[href='/feed/my']", text: "Feeds")
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/my")
    |> assert_has("#sidebar-feed-my[aria-current='page']", text: "Following", timeout: 2000)
  end

  test "loading a feed starts collapsed and keeps the disclosure available" do
    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#sidebar-feeds-list:not([open])", timeout: 2000)
    |> assert_has("#sidebar-feeds-list > summary[aria-label='Expand or collapse feeds']")
    |> assert_has("#sidebar-feed-my[aria-current='page']", timeout: 2000)
  end

  test "default feed can be changed in settings" do
    conn(user: fake_user!())
    |> visit("/settings/user/feeds")
    |> PhoenixTest.select("Default feed", option: "Local")
    |> visit("/")
    |> wait_async()
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/local")
    |> assert_has("#sidebar-feed-local[aria-current='page']", timeout: 2000)
  end

  test "custom presets are selectable even when hidden from sidebar navigation" do
    user = fake_user!()
    name = Faker.Lorem.sentence()

    assert {:ok, _} =
             Bonfire.Common.Settings.put(
               [:bonfire_social, Bonfire.Social.Feeds, :feed_presets, :sidebar_custom],
               %{
                 name: name,
                 icon: "ph:rss-simple-fill",
                 exclude_from_nav: true,
                 filters: %{feed_name: :local}
               },
               current_user: user
             )

    conn(user: user)
    |> visit("/settings/user/feeds")
    |> assert_has("#default-feed-select option[value='sidebar_custom']", text: name)
    |> PhoenixTest.select("Default feed", option: name)
    |> visit("/")
    |> wait_async()
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/sidebar_custom")
    |> refute_has("#sidebar-feed-sidebar_custom")
  end

  test "a removed default falls back to Following" do
    user = fake_user!()

    assert {:ok, _} =
             Bonfire.Common.Settings.put(
               [Bonfire.UI.Social.FeedLive, :default_feed],
               "deleted-feed",
               current_user: user
             )

    conn(user: user)
    |> visit("/")
    |> wait_async()
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/my")
  end
end
