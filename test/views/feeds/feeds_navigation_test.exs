defmodule Bonfire.UI.Social.FeedsNavigation.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  describe "feed navigation" do
    test "user can navigate between different feed types", %{} do
      account = fake_account!()
      user = fake_user!(account)

      conn(user: user, account: account)
      |> visit("/feed")
      |> click_link("li a", "Following")
      |> assert_path("/feed/my")
      |> click_link("li a", "Explore")
      |> assert_path("/feed/explore")

      # Note: "Likes" and "Bookmarks" feeds are currently commented out in the navigation
      # |> click_link("li a", "Likes")
      # |> assert_path("/feed/likes")
      # |> click_link("li a", "Bookmarks")
      # |> assert_path("/feed/bookmarks")

      # |> click_link("li a", "Discussions")
      # |> assert_path("/feed/filter/discussions")
    end

    # FIXME (regression from the filters-in-widget move): the inline sort dropdown
    # (#order_dropdown_feed, from SortItemsDropdownLive via FeedControlsLive) is no longer
    # rendered on feed pages — the customize widget's advanced editor only exposes sort_order
    # (Newest/Oldest first), not sort_by (most replied/boosted/liked). Needs a product decision
    # (re-add a sort_by control somewhere) before this can be re-enabled.
    @tag :fixme
    test "user can apply different sorting options", %{} do
      # The inline sort dropdown (#order_dropdown_feed) exposes sort_by options
      # (chronological / most replied / most boosted / most liked) as menu
      # buttons. The selected option is reflected in the trigger button label.
      conn(user: fake_user!())
      |> visit("/feed")
      |> click_button(
        "#order_dropdown_feed button[phx-value-sort_by='reply_count']",
        "Most replied"
      )
      |> assert_has("#order_dropdown_feed_trigger", text: "Most replied")
      |> click_button(
        "#order_dropdown_feed button[phx-value-sort_by='boost_count']",
        "Most boosted"
      )
      |> assert_has("#order_dropdown_feed_trigger", text: "Most boosted")
      |> click_button("#order_dropdown_feed button[phx-value-sort_by='like_count']", "Most liked")
      |> assert_has("#order_dropdown_feed_trigger", text: "Most liked")
      |> click_button(
        "#order_dropdown_feed button[phx-value-sort_by='date_created']",
        "Chronological"
      )
      |> assert_has("#order_dropdown_feed_trigger", text: "Chronological")
    end

    test "user can change sort order", %{} do
      # Sort direction (Oldest/Newest first) now lives in the advanced-filters editor,
      # expanded inline from the customize-feed sidebar widget. The expander stays open
      # after applying, so the active-filter chip is asserted without re-opening.
      conn(user: fake_user!())
      |> visit("/feed")
      |> wait_async()
      |> click_button("[data-role=open_modal]", "Advanced filters")
      |> click_button("Oldest first")
      |> click_button("Apply filters")
      |> wait_async()
      |> assert_has("button[aria-label='Remove filter: Oldest first']")
    end

    @tag :todo
    test "handles non-existent feed gracefully", %{} do
      conn(user: fake_user!())
      |> visit("/feed/nonexistent")
      # Assuming there's an error message class
      |> assert_has(".error-message")
    end
  end
end
