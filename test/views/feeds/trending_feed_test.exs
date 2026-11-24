defmodule Bonfire.UI.Social.TrendingFeedTest do
  @moduledoc "The trending feed pages through its cached ranking with fixed filters, and drops posts by authors the viewer silenced, as the cached widgets do."
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Boundaries.Blocks
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.FeedLoader

  setup do
    Process.put(:federating, false)
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)
    author = fake_user!(fake_account!())
    bystander = fake_user!(fake_account!())
    boosters = for _ <- 1..3, do: fake_user!(fake_account!())

    for {user, text, count} <- [
          {author, "most boosted, by the author", 3},
          {bystander, "second, by a bystander", 2},
          {bystander, "third, by a bystander", 1}
        ] do
      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: user,
          post_attrs: %{post_content: %{html_body: text}},
          boundary: "public"
        )

      for booster <- Enum.take(boosters, count), do: {:ok, _} = Boosts.boost(booster, post)
    end

    # the cached lists are global: drop any left by another test, for both circles and the page sizes used here
    for limit <- [1, 2], user <- [me, nil] do
      FeedLoader.feed(:trending, %{}, current_user: user, paginate: [limit: limit], cache: :reset)
    end

    {:ok, conn: conn(user: me, account: account), me: me, author: author}
  end

  defp trending(conn) do
    conn
    |> visit("/feed/trending")
    |> wait_async()
  end

  test "pages through the ranking to its end, with no feed preferences to change", %{conn: conn} do
    Process.put([:bonfire, :default_pagination_limit], 1)

    trending(conn)
    |> assert_has("[data-id=feed] article", text: "most boosted, by the author")
    |> refute_has("[data-role=feed_preferences_widget]")
    |> click_button("[data-id=load_more]", "Load more")
    |> wait_async()
    |> assert_has("[data-id=feed] article", text: "second, by a bystander")
    |> click_button("[data-id=load_more]", "Load more")
    |> wait_async()
    |> assert_has("[data-id=feed] article", text: "third, by a bystander")
    |> refute_has("[data-id=load_more]")
    # the window is part of the preset, and the list may end at its page cap: no "Last N days", no way to widen it
    |> refute_has("[data-id=load_all_time]")
    |> refute_has("button", text: "Show older activities")
    |> refute_has("p", text: "Last 7 days")
    |> assert_has("p", text: "That's all folks...")
  end

  # a popularity sort can't go past the max window (it would score every post), so once there, there is nothing older to show
  test "a popularity-sorted feed stops offering older activities at the max window", %{conn: conn} do
    conn
    |> visit("/feed/trending_links")
    |> wait_async()
    |> assert_has("p", text: "Last 7 days")
    |> click_button("[data-id=load_all_time]", "Show older activities")
    |> wait_async()
    |> assert_has("p", text: "Last 30 days")
    |> refute_has("[data-id=load_all_time]")
  end

  test "drops a post once I silence its author, without waiting for the cache", %{
    conn: conn,
    me: me,
    author: author
  } do
    Process.put([:bonfire, :default_pagination_limit], 2)

    # the positive first, which also fills the cache
    trending(conn)
    |> assert_has("[data-id=feed] article", text: "most boosted, by the author")

    Blocks.block(author, :silence, current_user: me)

    trending(conn)
    |> assert_has("[data-id=feed] article", text: "second, by a bystander")
    |> refute_has("[data-id=feed] article", text: "most boosted, by the author")
  end
end
