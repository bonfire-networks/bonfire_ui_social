defmodule Bonfire.UI.Social.FeedsNavigation.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  describe "feed navigation" do
    test "user can navigate between different feed types", %{} do
      account = fake_account!()
      user = fake_user!(account)

      conn(user: user, account: account)
      |> visit("/feed")
      |> click_link("li a", "Following")
      |> assert_path("/feed/my")
      |> wait_async()
      |> refute_has("[data-role=feed_source_toggle]")
      |> click_link("li a", "Explore")
      |> assert_path("/feed/explore")
      |> wait_async()
      |> refute_has("[data-role=feed_source_toggle]")

    end

    test "user can change ranking and return to chronological order" do
      session =
        conn(user: fake_user!())
        |> visit("/feed")
        |> wait_async()

      Enum.reduce(
        [{"Most replied", "reply_count"}, {"Most boosted", "boost_count"},
         {"Most liked", "like_count"}, {"Oldest first", "oldest"}, {"Newest first", "newest"}],
        session,
        fn {label, value}, session ->
          session
          |> PhoenixTest.select("Order", option: label)
          |> wait_async()
          |> assert_has("select[name=feed_order] option[value='#{value}'][selected]")
        end
      )
    end

  end
end
