defmodule Bonfire.UI.Social.FeedsNavigation.Test do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  describe "feed navigation" do
    test "user can navigate between different feed types", %{} do
      account = fake_account!()
      user = fake_user!(account)

      conn(user: user, account: account)
      |> visit("/feed")
      |> click_link("#feed-tabs a", "Following")
      |> assert_path("/feed/my")
      |> wait_async()
      |> refute_has("[data-role=feed_source_toggle]")
      |> click_link("#feed-tabs a", "Explore")
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
        [
          {"Most replied", "reply_count"},
          {"Most boosted", "boost_count"},
          {"Most liked", "like_count"},
          {"Oldest first", "oldest"},
          {"Newest first", "newest"}
        ],
        session,
        fn {label, value}, session ->
          session
          |> PhoenixTest.select("Sort", option: label)
          |> wait_async()
          |> assert_has("select[name=feed_order] option[value='#{value}'][selected]")
        end
      )
    end

    test "with no top sections, Happening is inside More filters and not above them" do
      conn(user: fake_user!())
      |> visit("/feed/local")
      |> wait_async()
      |> refute_has("[data-role=feed_top_filters]")
      |> refute_has("[data-row=happening]")
      |> click_button("[data-role=open_modal]", "More filters")
      |> assert_has("[data-role=feed_advanced_filters_wrapper] [data-row=happening]")
    end

    test "the sort offers Soonest first only with a Happening filter set" do
      conn(user: fake_user!())
      |> visit("/feed/local")
      |> wait_async()
      # control: the other orders are there
      |> assert_has("select[name=feed_order] option[value=oldest]")
      |> refute_has("select[name=feed_order] option[value=starts_at]")
      |> click_button("[data-role=open_modal]", "More filters")
      |> unwrap(fn view ->
        view
        |> Phoenix.LiveViewTest.element("[data-row=happening] form[phx-change]")
        |> Phoenix.LiveViewTest.render_change(%{"happening" => "upcoming"})
      end)
      |> click_button("Apply filters")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=starts_at]", text: "Soonest first")
      |> PhoenixTest.select("Sort", option: "Soonest first")
      |> wait_async()
      |> assert_has("select[name=feed_order] option[value=starts_at][selected]")
    end
  end
end
