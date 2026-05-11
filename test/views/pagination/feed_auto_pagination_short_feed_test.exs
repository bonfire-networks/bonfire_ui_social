defmodule Bonfire.UI.Social.Feeds.AutoPaginationShortFeedTest do
  @moduledoc """
  Direct regression test for the bug where a group/topic feed with too few
  activities to fill the viewport would auto-trigger the "Show older
  activities" LoadMore (via IntersectionObserver), which then misrouted
  through `Bonfire.Social.Feeds.LiveHandler.handle_event("load_more",
  %{"context" => feed_id}, ...)` and loaded ~10+ unrelated activities from
  other feeds.

  Fix: `feed_live.sface` now uses `dom_id_suffix="show_older"` instead of
  `context="show_older"`, so the auto-triggered load_more no longer carries
  a misleading `phx-value-context` and falls through to the proper
  fallback handler that uses `feed_filters.feed_ids` from socket assigns.

  This test mounts a short-feed scenario and asserts no foreign entries
  bleed in even when infinite-scroll is enabled (the configuration that
  makes the IntersectionObserver fire on mount).
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config
  alias Bonfire.Common.Settings
  alias Bonfire.Posts
  alias Bonfire.Classify.Simulate

  setup do
    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)

    on_exit(fn ->
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
    end)

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    account = fake_account!()
    me = fake_user!(account)

    %{account: account, me: me}
  end

  describe "group feed with fewer entries than viewport" do
    test "infinite-scroll mode does not pull in unrelated activities", %{
      account: account,
      me: me
    } do
      # Enable doom-scroll so phx-scroll auto-fires load_more on mount.
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      # A group with only 2 posts (far less than `default_pagination_limit`).
      group = Simulate.fake_group!(me, %{name: "Tiny Group"})
      Simulate.fake_post_in_group!(me, group, "<p>tiny group post A</p>")
      Simulate.fake_post_in_group!(me, group, "<p>tiny group post B</p>")

      # And many unrelated posts in the user's local feed: these would leak
      # in if load_more falls through to the unfiltered explore branch.
      for n <- 1..15 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>foreign post #{n}</p>"}},
            boundary: "public"
          )
      end

      conn = conn(user: me, account: account)

      # Regression: with doom-scroll on and only 2 entries, the "Show older"
      # LoadMore's IntersectionObserver fires on mount and used to misroute
      # through the context="show_older" stale clause, leaking foreign posts.
      conn
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has_or_open_browser("article", text: "tiny group post A")
      |> assert_has("article", text: "tiny group post B")
      |> refute_has_or_open_browser("article", text: "foreign post")
    end

    test "preload mode does not pull in unrelated activities either", %{
      account: account,
      me: me
    } do
      Settings.put([:ui, :infinite_scroll], :preload, current_user: me, scope: :user)

      group = Simulate.fake_group!(me, %{name: "Tiny Preload Group"})
      Simulate.fake_post_in_group!(me, group, "<p>preload group post 1</p>")
      Simulate.fake_post_in_group!(me, group, "<p>preload group post 2</p>")

      for n <- 1..15 do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>foreign preload post #{n}</p>"}},
            boundary: "public"
          )
      end

      conn = conn(user: me, account: account)

      conn
      |> visit("/&#{group.character.username}")
      |> wait_async()
      |> assert_has("article", text: "preload group post 1")
      |> assert_has("article", text: "preload group post 2")
      |> refute_has("article", text: "foreign preload post")
    end
  end

  describe "Show older activities LoadMore" do
    test "does not carry phx-value-context (uses dom_id_suffix instead)", %{
      account: account,
      me: me
    } do
      # Span multiple days so the "Show older" LoadMore renders below the
      # primary LoadMore. Reuse the existing fake_post helper.
      alias Bonfire.Common.DatesTimes
      import Bonfire.Posts.Fake, only: [fake_post!: 3]

      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      fake_post!(me, "public", %{
        post_content: %{html_body: "<p>today</p>"},
        id: DatesTimes.now() |> DatesTimes.generate_ulid()
      })

      for n <- 1..5 do
        fake_post!(me, "public", %{
          post_content: %{html_body: "<p>old #{n}</p>"},
          id: DatesTimes.past(n + 2, :day) |> DatesTimes.generate_ulid()
        })
      end

      conn(user: me, account: account)
      |> visit("/feed/local?time_limit=1")
      |> assert_has("#load_more_show_older[data-id=load_more]")
      # Crucially: no `phx-value-context` attr on the show_older LoadMore.
      # Phoenix omits the attr entirely when the bound expression is nil,
      # so the stale `%{"context" => feed_id}` clause in the Feeds
      # LiveHandler can no longer match.
      |> refute_has(~s|#load_more_show_older[phx-value-context]|)
    end
  end
end
