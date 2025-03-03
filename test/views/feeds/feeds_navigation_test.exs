defmodule Bonfire.UI.Social.FeedsNavigation.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  describe "feed navigation" do
    test "user can navigate between different feed types", %{} do
      conn(user: fake_user!())
      |> visit("/")
      |> click_link("[data-id=nav_sidebar_nav_links] a", "Following")
      |> assert_path("/feed/my")
      |> click_link("[data-id=nav_sidebar_nav_links] a", "Local")
      |> assert_path("/feed/local")
      |> click_link("[data-id=nav_sidebar_nav_links] a", "Remote")
      |> assert_path("/feed/fediverse")
      |> click_link("[data-id=nav_sidebar_nav_links] a", "Posts")
      |> assert_path("/feed/posts")

      # |> click_link("[data-id=nav_sidebar_nav_links] a", "Discussions")
      # |> assert_path("/feed/filter/discussions")
    end

    test "user can apply different sorting options", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # Open the sort dropdown and select different options
      |> click_link("#order_dropdown_feed a", "Most replied")
      |> assert_has("#order_dropdown_feed label", text: "Most replied")
      |> click_link("#order_dropdown_feed a", "Most boosted")
      |> assert_has("#order_dropdown_feed label", text: "Most boosted")
      |> click_link("#order_dropdown_feed a", "Most liked")
      |> assert_has("#order_dropdown_feed label", text: "Most liked")
      |> click_link("#order_dropdown_feed a", "Chronological")
      |> assert_has("#order_dropdown_feed label", text: "Chronological")
    end

    test "user can change sort order", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      |> within("#sort_timing_feed", fn session ->
        session
        #  FIXME
        |> click_link("Oldest first")
        |> assert_has("label span", text: "Oldest first")
        |> click_link("Newest first")
        |> assert_has("label span", text: "Newest first")
      end)
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
