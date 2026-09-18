defmodule Bonfire.UI.Social.NotificationShowInCentreTest do
  @moduledoc """
  The "Show in centre" switches on the notifications feed.

  Each switch hides one category from the notifications feed, as a read-time feed filter: the
  activity is still there, and its chip stays reachable, greyed. Categories, their order and their
  labels come from `Bonfire.Social.Notifications`, so a switch hides exactly what its chip shows.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Notifications
  alias Bonfire.Common.Settings
  alias Bonfire.UI.Social.NotificationPreferencesLive

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)
    Process.put([:bonfire, :default_pagination_limit], 10)

    me = fake_user!("centre_me")
    other = fake_user!("centre_other")

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "a post of mine to react to"}},
        boundary: "public"
      )

    {:ok, _like} = Likes.like(other, post)
    {:ok, _boost} = Boosts.boost(other, post)

    {:ok, conn: conn(user: me, account: me.account), me: me}
  end

  # what the feed was actually queried with, as strings, since the filter accepts atoms or strings
  defp excluded(session) do
    live_assigns(session)[:feed_filters]
    |> e(:exclude_activity_types, [])
    |> Enum.map(&to_string/1)
  end

  test "rows render from the shared category list, in its order" do
    doc =
      render_component(&NotificationPreferencesLive.render/1, %{__context__: %{}})
      |> Floki.parse_document!()

    rows = NotificationPreferencesLive.notification_rows()

    assert Floki.attribute(doc, "[id$=-centre]", "id") ==
             Enum.map(rows, fn {key, _label, _wired?} -> "notification-pref-#{key}-centre" end)

    for {key, label, _wired?} <- rows do
      assert [_] = Floki.find(doc, "#notification-pref-#{key}-centre")
      assert Floki.raw_html(doc) =~ label
    end
  end

  test "a switched-off category is excluded from the feed, and stays excluded across chips", %{
    conn: conn,
    me: me
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("[data-verb=Boost]")
    |> assert_has("[data-verb=Like]")

    Settings.put(Notifications.show_in_centre_key(:boost), false, current_user: me)

    session =
      conn(user: me, account: me.account)
      |> visit("/notifications")
      |> wait_async()
      |> assert_has("[data-verb=Like]")
      |> refute_has("[data-verb=Boost]")

    assert excluded(session) == ["boost"]

    # the chips go through the same rebuild, so a visit to two of them doesn't lose the exclusion
    session
    |> click_link("#notification-filter-like", "Likes")
    |> wait_async()
    |> click_link("#notification-filter-latest", "Latest")
    |> wait_async()
    |> assert_has("[data-verb=Like]")
    |> refute_has("[data-verb=Boost]")
  end

  test "a switched-off category's chip greys out and stays a link", %{conn: conn, me: me} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> refute_has("#notification-filter-boost[class*=opacity-40]")
    |> refute_has("#notification-filters-dimmed")

    Settings.put(Notifications.show_in_centre_key(:boost), false, current_user: me)

    conn(user: me, account: me.account)
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-boost[class*=opacity-40]")
    |> assert_has("#notification-filter-boost[href='/notifications/boosts']")
    |> refute_has("#notification-filter-like[class*=opacity-40]")
    # dimming is colour alone, so the state is spoken too, and only by the chips it applies to
    |> assert_has("#notification-filters-dimmed")
    |> assert_has("#notification-filter-boost[aria-describedby=notification-filters-dimmed]")
    |> refute_has("#notification-filter-like[aria-describedby=notification-filters-dimmed]")
  end

  test "the chip of a switched-off category still shows it", %{conn: conn, me: me} do
    Settings.put(Notifications.show_in_centre_key(:boost), false, current_user: me)

    conn(user: me, account: me.account)
    |> visit("/notifications/boosts")
    |> wait_async()
    |> assert_has("[data-verb=Boost]")
  end

  test "switching a category off in the panel offers Apply, which catches the feed up", %{
    conn: conn
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> refute_has("#notification-display-apply")
    |> uncheck("#notification-pref-boost-centre", "Boosts: show in Latest notifications")
    # saved, but the feed is only re-queried on demand
    |> assert_has("#notification-display-apply")
    |> assert_has("[data-verb=Boost]")
    |> click_button("#notification-display-apply button", "Apply to feed")
    |> wait_async()
    |> refute_has("[data-verb=Boost]")
    |> assert_has("[data-verb=Like]")
    |> refute_has("#notification-display-apply")
  end

  test "a category excludes what its chip filters by, not just its key", %{me: me} do
    # Mentions is `:create` on both surfaces until Phase 4's tagged-me predicate
    assert Notifications.activity_types_for(:mention) == [:create]

    Settings.put(Notifications.show_in_centre_key(:mention), false, current_user: me)

    session = conn(user: me, account: me.account) |> visit("/notifications") |> wait_async()
    assert excluded(session) == ["create"]
  end
end
