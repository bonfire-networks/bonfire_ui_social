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
      |> within("data-id[nav_links]", fn session ->
        session
        |> click_link("Following")
        |> assert_path("/feed/my")
        |> click_link("Local")
        |> assert_path("/feed/local")
        |> click_link("Remote")
        |> assert_path("/feed/fediverse")
        |> click_link("Posts")
        |> assert_path("/feed/my/posts")
        |> click_link("Discussions")
        |> assert_path("/feed/my/discussions")
      end)
    end

    test "user can apply different sorting options", %{} do
      conn(user: fake_user!())
      |> visit("/feed")
      # Open the sort dropdown and select different options
      |> within("#order_dropdown_feed", fn session ->
        session
        |> click_link("By amount of replies")
        |> assert_has(".active", text: "By amount of replies")
        |> click_link("By amount of boosts")
        |> assert_has(".active", text: "By amount of boosts")
        |> click_link("By amount of likes")
        |> assert_has(".active", text: "By amount of likes")
        |> click_link("Chronological")
        |> assert_has(".active", text: "Chronological")
      end)
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
