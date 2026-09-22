defmodule Bonfire.UI.Social.SaveCustomFeedTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  test "save is hidden until preferences change and hides again after reset" do
    conn(user: fake_user!())
    |> visit("/feed/local")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
    |> uncheck("Replies")
    |> wait_async()
    |> assert_has("[data-role=save_custom_feed] summary", text: "Save as custom feed")
    |> check("Replies")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
    |> PhoenixTest.select("Sort", option: "Oldest first")
    |> wait_async()
    |> assert_has("[data-role=save_custom_feed]")
    |> click_button("Reset feed preferences")
    |> wait_async()
    |> refute_has("[data-role=save_custom_feed]")
  end

  for show_in_nav <- [true, false], set_as_default <- [true, false] do
    test "save with navbar=#{show_in_nav} and default=#{set_as_default}" do
      name = "saved-" <> Faker.Lorem.word() <> "-" <> to_string(System.unique_integer([:positive]))

      session =
        conn(user: fake_user!())
        |> visit("/feed/local")
        |> wait_async()
        |> uncheck("Boosts")
        |> wait_async()
        |> assert_has("[data-role=save_custom_feed]")
        |> fill_in("Feed title", with: name)
        |> fill_in("Feed description", with: "My saved preferences")

      session =
        if unquote(show_in_nav),
          do: session,
          else: uncheck(session, "Show in feeds navbar")

      session =
        if unquote(set_as_default),
          do: check(session, "Set as default feed"),
          else: session

      session =
        session
        |> click_button("Save feed")
        |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
        |> wait_async()
        |> assert_has("#feed-description-title", text: name)
        |> assert_has("input[name='scope[boosts]']:not(:checked)")

      session =
        if unquote(show_in_nav),
          do: assert_has(session, "#feed-tabs a", text: name),
          else: refute_has(session, "#feed-tabs a", text: name)

      session
      |> click_link("#sidebar-feeds-link", "Feeds")
      |> assert_path(if(unquote(set_as_default), do: "/feed/#{name}", else: "/feed/my"))
    end
  end
end
