defmodule Bonfire.UI.Social.Feeds.MyBoostsFeedTest do
  @moduledoc """
  My boosts shows the feed controls that make sense on it, so a reader can narrow what they boosted and save the result as a custom feed. The controls that would empty it or make it another feed (activity type, Replies, Boosts, and the people controls, which act on who boosted, always the reader) are left out.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Social.Boosts

  # a tagged post I boosted, a plain post I boosted, a tagged post someone else boosted, and a tagged post nobody boosted: the hashtag filter acts on the boosted post, and My boosts on who boosted it
  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!()
    bob = fake_user!()

    post = fn author, text ->
      Bonfire.Posts.Fake.fake_post!(author, "public", %{post_content: %{html_body: text}})
    end

    tagged = post.(alice, "about #noctilucent boosts")
    plain = post.(alice, "a plain post I boosted")
    alices = post.(alice, "another #noctilucent boost")
    post.(alice, "unboosted #noctilucent post")

    {:ok, _} = Boosts.boost(me, tagged)
    {:ok, _} = Boosts.boost(me, plain)
    {:ok, _} = Boosts.boost(bob, alices)

    %{conn: conn(user: me, account: account)}
  end

  defp path, do: Bonfire.UI.Social.FeedNavigation.build_path(:my_boosts)

  defp filter_by_noctilucent(session) do
    session
    |> click_button("[data-role=open_modal]", "More filters")
    |> fill_in("Hashtags", with: "noctilucent")
    |> click_button("Apply filters")
    |> wait_async()
  end

  defp refute_other_boosts(session) do
    session
    |> refute_has("[data-id=object_body]", text: "a plain post I boosted")
    |> refute_has("[data-id=object_body]", text: "another #noctilucent boost")
    |> refute_has("[data-id=object_body]", text: "unboosted #noctilucent post")
  end

  test "My boosts shows the feed controls, without activity type, people, Replies or Boosts", %{
    conn: conn
  } do
    conn
    |> visit(path())
    |> wait_async()
    |> assert_has("[data-role=feed_advanced_filters]")
    |> refute_has("input[name='scope[replies]']")
    |> refute_has("input[name='scope[boosts]']")
    |> click_button("[data-role=open_modal]", "More filters")
    |> assert_has("[data-row=hashtags]")
    |> refute_has("[data-row=activity_types]")
    |> refute_has("[data-row=hide_own]")
    |> refute_has("[data-row=from_people]")
    |> refute_has("[data-row=not_people]")
  end

  test "a hashtag narrows My boosts to my boosted posts with it", %{conn: conn} do
    conn
    |> visit(path())
    |> wait_async()
    |> filter_by_noctilucent()
    |> assert_has("[data-id=object_body]", text: "about #noctilucent boosts")
    |> refute_other_boosts()
  end

  test "a feed saved from a filtered My boosts reopens with only my boosts with that tag", %{
    conn: conn
  } do
    name = "saved-boosts-" <> to_string(System.unique_integer([:positive]))

    conn
    |> visit(path())
    |> wait_async()
    |> filter_by_noctilucent()
    |> fill_in("Feed title", with: name)
    |> click_button("Save feed")
    |> visit("/settings/user/feeds")
    |> visit(Bonfire.UI.Social.FeedNavigation.build_path(name))
    |> wait_async()
    |> assert_has("#feed-description-title", text: name)
    |> assert_has("[data-id=object_body]", text: "about #noctilucent boosts")
    |> refute_other_boosts()
  end
end
