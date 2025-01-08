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
      |> click_link("nav [data-id=nav_links] a", "Following")
      |> assert_path("/feed/my")
      |> click_link("nav [data-id=nav_links] a", "Local")
      |> assert_path("/feed/local")
      |> click_link("nav [data-id=nav_links] a", "Remote")
      |> assert_path("/feed/fediverse")
      |> click_link("nav [data-id=nav_links] a", "Posts")
      |> assert_path("/feed/filter/posts")
      |> click_link("nav [data-id=nav_links] a", "Discussions")
      |> assert_path("/feed/filter/discussions")
    end

    test "user can apply different sorting options", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # Open the sort dropdown and select different options
      |> click_link("#order_dropdown_feed a", "By amount of replies")
      |> assert_has("#order_dropdown_feed label", text: "By amount of replies")
      |> click_link("#order_dropdown_feed a", "By amount of boosts")
      |> assert_has("#order_dropdown_feed label", text: "By amount of boosts")
      |> click_link("#order_dropdown_feed a", "By amount of likes")
      |> assert_has("#order_dropdown_feed label", text: "By amount of likes")
      |> click_link("#order_dropdown_feed a", "Chronological")
      |> assert_has("#order_dropdown_feed label", text: "Chronological")
    end

    test "user can change sort order", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      |> within("#sort_timing_feed", fn session ->
        session
        |> click_link("Oldest first")
        |> assert_has(".active", text: "Oldest first")
        |> click_link("Newest first")
        |> assert_has(".active", text: "Newest first")
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
