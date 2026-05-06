defmodule Bonfire.UI.Social.InfiniteScrollSettingsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  use Bonfire.Common.Config
  alias Bonfire.Common.Settings
  alias Bonfire.Posts
  alias Bonfire.Common.DatesTimes
  import Bonfire.Posts.Fake, only: [fake_post!: 3]

  # NOTE: `config/test.exs` forces `[:ui, :infinite_scroll]` to `false` at the
  # config level (presumably to keep IntersectionObserver-driven loading out
  # of PhoenixTest, where JS hooks don't run). We override per-test using
  # `Settings.put(..., scope: :user)` since user-scope settings take
  # precedence over the config fallback.

  setup do
    account = fake_account!()
    me = fake_user!(account)
    {:ok, conn: conn(user: me, account: account), me: me, account: account}
  end

  describe "feed renders the LoadMore element according to the setting" do
    setup %{me: me} do
      # Deferred joins change pagination/cursor rendering enough that the
      # `phx-scroll` attribute may not appear; disable as the existing
      # pagination tests do.
      original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)

      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
      end)

      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      # Need more activities than `default_pagination_limit` for the load_more button to render
      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)

      for n <- 1..(limit * 2) do
        {:ok, _} =
          Posts.publish(
            current_user: me,
            post_attrs: %{post_content: %{html_body: "<p>post #{n}</p>"}},
            boundary: "public"
          )
      end

      :ok
    end

    test "`:preload` — scroll triggers `preload_more` and uses the LoadMore hook",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], :preload, current_user: me, scope: :user)

      session =
        conn
        |> visit("/feed/local")
        |> assert_has(~s|[data-id=load_more][phx-scroll$=":preload_more"]|)

      # not the immediate `load_more` event
      refute_has(session, ~s|[data-id=load_more][phx-scroll$=":load_more"]|)
    end

    test "doom scrolling (`true`) — scroll triggers `load_more` and uses the LoadMore hook",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      session =
        conn
        |> visit("/feed/local")
        |> assert_has(~s|[data-id=load_more][phx-scroll$=":load_more"]|)

      # not the deferred `preload_more` event
      refute_has(session, ~s|[data-id=load_more][phx-scroll$=":preload_more"]|)
    end

    test "disabled (`false`) — button still rendered, but no scroll auto-trigger",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], false, current_user: me, scope: :user)

      session =
        conn
        |> visit("/feed/local")
        |> assert_has("[data-id=load_more]")

      # No phx-scroll attribute → no IntersectionObserver-driven autoload
      refute_has(session, "[data-id=load_more][phx-scroll]")
    end
  end

  describe "time-limit boundary — 'Show older activities' button" do
    setup %{me: me} do
      original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)

      on_exit(fn ->
        Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
      end)

      repo().delete_all(Bonfire.Data.Social.FeedPublish)

      # Posts spanning multiple windows, so that with time_limit=1 we
      # exhaust the in-window cursor and reach the secondary LoadMoreLive
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

      :ok
    end

    test "in doom mode (`true`) the 'Show older activities' button auto-triggers via phx-scroll",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      conn
      |> visit("/feed/local?time_limit=1")
      |> assert_has("[data-id=load_more]", text: "Show older activities")
      # In doom mode the secondary button must autoload on scroll, NOT just on click
      |> assert_has(~s|[data-id=load_more][phx-scroll$=":load_more"]|)
    end

    test "in `:preload` mode the 'Show older activities' button uses preload_more",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], :preload, current_user: me, scope: :user)

      conn
      |> visit("/feed/local?time_limit=1")
      |> assert_has("[data-id=load_more]", text: "Show older activities")
      |> assert_has(~s|[data-id=load_more][phx-scroll$=":preload_more"]|)
    end

    test "in disabled mode (`false`) the 'Show older activities' button only loads on click",
         %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], false, current_user: me, scope: :user)

      session =
        conn
        |> visit("/feed/local?time_limit=1")
        |> assert_has("[data-id=load_more]", text: "Show older activities")

      refute_has(session, "[data-id=load_more][phx-scroll]")
    end

    test "the 'Show older activities' button has a distinct DOM id from the primary",
         %{conn: conn, me: me} do
      # Distinct ids force LiveView to remount the hook so the IntersectionObserver re-arms.
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      conn
      |> visit("/feed/local?time_limit=1")
      |> assert_has("#load_more_show_older[data-id=load_more]", text: "Show older activities")
    end
  end

  describe "infinite-scroll toggle in feed settings UI" do
    test "toggle is unchecked by default", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> refute_has("#infinite_scroll_toggle[checked]")
    end

    test "checking the toggle persists `true` (doom scrolling)", %{conn: conn} do
      conn
      |> visit("/settings/user/feeds")
      |> within("form[data-scope=infinite_scroll]", fn session ->
        check(session, "Infinite scrolling", exact: false)
      end)
      # Revisit to confirm the toggle persisted as checked
      |> visit("/settings/user/feeds")
      |> assert_has("#infinite_scroll_toggle[checked]")
    end

    test "unchecking the toggle restores `:preload`", %{conn: conn, me: me} do
      Settings.put([:ui, :infinite_scroll], true, current_user: me, scope: :user)

      conn
      |> visit("/settings/user/feeds")
      |> assert_has("#infinite_scroll_toggle[checked]")
      |> within("form[data-scope=infinite_scroll]", fn session ->
        uncheck(session, "Infinite scrolling", exact: false)
      end)
      |> visit("/settings/user/feeds")
      |> refute_has("#infinite_scroll_toggle[checked]")
    end
  end
end
