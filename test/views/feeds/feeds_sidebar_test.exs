defmodule Bonfire.UI.Social.FeedsSidebarTest do
  use Bonfire.UI.Social.ConnCase, async: false

  @moduletag :ui

  test "feed details set a default without allowing it to be unset" do
    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#feed-description-default[disabled]", text: "Default feed")
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("#feed-description-default:not([disabled])", text: "Set as default feed")
    |> click_button("#feed-description-default", "Set as default feed")
    |> assert_has("#feed-description-default[disabled]", text: "Default feed")
    |> PhoenixTest.unwrap(fn view ->
      Phoenix.LiveViewTest.render_hook(view, "Bonfire.Social.Feeds:preset_set_default", %{
        "id" => "local"
      })

      Phoenix.LiveViewTest.render_hook(view, "Bonfire.Social.Feeds:preset_set_default", %{
        "id" => "unknown-feed"
      })
    end)
    |> assert_has("#feed-description-default[disabled]", text: "Default feed")
    |> visit("/settings/user/feeds")
    |> assert_has("#default-feed-select option[value=local][selected]")
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#feed-description-default:not([disabled])", text: "Set as default feed")
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/local")
    |> assert_has("#feed-description-default[disabled]", text: "Default feed")
  end

  test "Bookmarks remains in the sidebar when unpinned and has its own active state" do
    user = fake_user!()

    assert {:ok, _} =
             Bonfire.Common.Settings.put(
               [
                 :bonfire_social,
                 Bonfire.Social.Feeds,
                 :feed_presets,
                 :bookmarks,
                 :exclude_from_nav
               ],
               true,
               current_user: user
             )

    conn(user: user)
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#sidebar-feeds-link[aria-current=page]")
    |> assert_has("#sidebar-bookmarks-link[href='/feed/bookmarks']", text: "Bookmarks")
    |> refute_has("#feed-tab-bookmarks")
    |> click_link("#sidebar-bookmarks-link", "Bookmarks")
    |> assert_path("/feed/bookmarks")
    |> assert_has("#sidebar-bookmarks-link[aria-current=page]")
    |> refute_has("#sidebar-feeds-link[aria-current=page]")
  end

  test "Feeds opens Following and has no sidebar dropdown" do
    conn(user: fake_user!())
    |> visit("/")
    |> wait_async()
    |> refute_has("#sidebar-feeds-list")
    |> refute_has("#sidebar-feeds-settings")
    |> assert_has("#sidebar-feeds-link[href='/feed/my']", text: "Feeds")
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/my")
    |> assert_has("#feed-tab-my[aria-current='page']", text: "Following", timeout: 2000)
  end

  test "feed pages show navigation below the feed's own heading" do
    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> refute_has("#sidebar-feeds-list")
    # what the preset says it is, which for this one is its name, since it declares no page title of its own
    |> assert_has("h1[data-role=page_title]", text: "Following")
    |> assert_has("#feed-tabs[aria-label=Feeds]")
    |> assert_has("#feed-tab-my[aria-current='page']", timeout: 2000)
    |> assert_has("aside", text: "Posts and conversations from people you follow.")
  end

  test "the feed header gear opens settings even when sidebar customization is disabled" do
    Process.put(
      [Bonfire.Common.Config.top_level_otp_app(), :ui, :sidebar, :disable_feeds_customization],
      true
    )

    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("header #header-feed-settings[href='/settings/user/feeds']")
    |> refute_has("#feed-description-pin")
    |> assert_has("#feed-description-default")
    |> click_link("#header-feed-settings", "Feed settings")
    |> assert_path("/settings/user/feeds")
    |> assert_has("#default-feed-select")
    |> refute_has("#feed-presets-panel")
  end

  test "feed details can unpin and repin the current feed" do
    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#feed-description-title", text: "Following")
    |> assert_has("#feed-description", text: "Posts and conversations from people you follow.")
    |> refute_has("#feed-description dl")
    |> click_button("#feed-description-pin", "Unpin from feed tabs")
    |> refute_has("#feed-tab-my")
    |> assert_has("#feed-description-pin[aria-pressed=false]", text: "Pin to feed tabs")
    |> click_button("#feed-description-pin", "Pin to feed tabs")
    |> assert_has("#feed-tab-my")
    |> visit("/feed/my")
    |> wait_async()
    |> assert_has("#feed-description-pin[aria-pressed=true]", text: "Unpin from feed tabs")
  end

  test "tabs navigate between feeds and keep the Feeds heading" do
    conn(user: fake_user!())
    |> visit("/feed/my")
    |> wait_async()
    |> click_link("#feed-tab-local", "Local")
    |> assert_path("/feed/local")
    |> wait_async()
    |> assert_has("#feed-tab-local[aria-current='page']", text: "Local")
    |> refute_has("#feed-tab-my[aria-current='page']")
    # switching feeds switches the heading with it
    |> assert_has("h1[data-role=page_title]", text: "Explore local activities")
  end

  test "settings and feed details share the same pin state" do
    Process.put(
      [Bonfire.Common.Config.top_level_otp_app(), :ui, :sidebar, :disable_feeds_customization],
      false
    )

    conn(user: fake_user!())
    |> visit("/settings/user/feeds")
    |> assert_has("#pin-feed-preset-my[aria-pressed=true]", text: "Unpin from feed tabs")
    |> click_button("#pin-feed-preset-my", "Unpin from feed tabs")
    |> assert_has("#pin-feed-preset-my[aria-pressed=false]", text: "Pin to feed tabs")
    |> visit("/feed/my")
    |> wait_async()
    |> refute_has("#feed-tab-my")
    |> assert_has("#feed-description-pin[aria-pressed=false]", text: "Pin to feed tabs")
    |> click_button("#feed-description-pin", "Pin to feed tabs")
    |> visit("/settings/user/feeds")
    |> assert_has("#pin-feed-preset-my[aria-pressed=true]", text: "Unpin from feed tabs")
  end

  test "notifications keep their heading and do not show feed tabs" do
    conn(user: fake_user!())
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("h1[data-role=page_title]", text: "Notifications")
    |> refute_has("#feed-tabs")
    |> refute_has("#header-feed-settings")
    |> refute_has("#feed-description-pin")
    |> refute_has("#feed-description-default")
  end

  test "guests see permitted feed tabs" do
    conn()
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("#feed-tab-local[aria-current='page']", text: "Local")
    |> refute_has("#feed-tab-my")
    |> refute_has("#sidebar-bookmarks-link")
    |> assert_has("h1[data-role=page_title]", text: "Explore local activities")
    |> refute_has("#header-feed-settings")
    |> assert_has("#feed-description",
      text: "Posts and conversations from people on this server."
    )
    |> refute_has("#feed-description dl")
    |> refute_has("#feed-description-pin")
    |> refute_has("#feed-description-default")
  end

  test "default feed can be changed in settings" do
    conn(user: fake_user!())
    |> visit("/settings/user/feeds")
    |> PhoenixTest.select("Default feed", option: "Local")
    |> visit("/")
    |> wait_async()
    |> click_link("#sidebar-feeds-link", "Feeds")
    |> assert_path("/feed/local")
    |> assert_has("#feed-tab-local[aria-current='page']", timeout: 2000)
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
    |> refute_has("#feed-tab-sidebar_custom")
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
