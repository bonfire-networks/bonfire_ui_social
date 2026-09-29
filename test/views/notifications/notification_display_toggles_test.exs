defmodule Bonfire.UI.Social.NotificationDisplayTogglesTest do
  @moduledoc """
  Per-user display switches on the notifications feed.

  Each switch is declared in config and names what it controls: a feed filter, a feed assign, or the
  chip bar. Its saved value survives a revisit, and defaults mirror the `:notifications` preset.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Likes
  alias Bonfire.Common.Settings
  alias Bonfire.UI.Social.NotificationPreferencesLive

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)
    Process.put([:bonfire, :default_pagination_limit], 10)

    me = fake_user!("toggles_me")
    other = fake_user!("toggles_other")

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "a post of mine to like"}},
        boundary: "public"
      )

    {:ok, _like} = Likes.like(other, post)

    {:ok, conn: conn(user: me, account: me.account), me: me}
  end

  test "switches render from config, in config order, reflecting their defaults" do
    doc =
      render_component(&NotificationPreferencesLive.render/1, %{__context__: %{}})
      |> Floki.parse_document!()

    for {key, toggle} <- NotificationPreferencesLive.extra_toggles() do
      assert [_] = Floki.find(doc, "#notification-display-#{key}")
      # the text, since raw HTML escapes a label's apostrophes (`I&#39;m`)
      assert Floki.text(doc) =~ toggle[:name]

      checked? = Floki.find(doc, "#notification-display-#{key}[checked]") != []
      assert checked? == (toggle[:default] == true)
    end
  end

  test "a saved switch leaves the shown feed alone until Apply", %{conn: conn, me: me} do
    session = conn |> visit("/notifications") |> wait_async()
    assert live_assigns(session)[:enable_marker] != true
    refute_has(session, "#notification-display-apply")

    # as `SettingsToggleLive` would, without reloading the feed
    Settings.put(NotificationPreferencesLive.display_setting_key(:highlight), true,
      current_user: me
    )

    session = conn(user: me, account: me.account) |> visit("/notifications") |> wait_async()

    # already applied on a fresh visit, so nothing is pending
    assert live_assigns(session)[:enable_marker] == true
    refute_has(session, "#notification-display-apply")
  end

  # not about the feed at all: whether what you write enables notifications of the replies below it, which the write path reads (`Bonfire.Notify.Bells.enable_thread_notifications_changeset/3`)
  test "the replies switch is on by default, turns off what your new posts enable, and never asks to Apply",
       %{conn: conn, me: me} do
    assert NotificationPreferencesLive.display_setting_key(:notify_any_replies) ==
             [:notifications, :notify_any_replies]

    # the positive first: on by default, so a new post of mine enables them
    {:ok, before} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "replies welcome"}},
        boundary: "public"
      )

    assert Bonfire.Notify.Bells.enabled?(me, before)

    me =
      Bonfire.Common.Utils.current_user(
        Settings.put(NotificationPreferencesLive.display_setting_key(:notify_any_replies), false,
          current_user: me
        )
      )

    {:ok, after_off} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "quiet please"}},
        boundary: "public"
      )

    refute Bonfire.Notify.Bells.enabled?(me, after_off)

    conn(user: me, account: me.account)
    |> visit("/notifications")
    |> wait_async()
    |> refute_has("#notification-display-apply")
  end

  test "the chip bar switch hides and shows the chips", %{conn: conn, me: me} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filters")

    Settings.put(NotificationPreferencesLive.display_setting_key(:chips), false, current_user: me)

    conn(user: me, account: me.account)
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("[data-id=feed]")
    |> refute_has("#notification-filters")
  end

  test "the unread-highlight switch drives the feed's marker assign", %{conn: conn, me: me} do
    off = conn |> visit("/notifications") |> wait_async()
    assert live_assigns(off)[:enable_marker] != true

    Settings.put(NotificationPreferencesLive.display_setting_key(:highlight), true,
      current_user: me
    )

    on = conn(user: me, account: me.account) |> visit("/notifications") |> wait_async()
    assert live_assigns(on)[:enable_marker] == true
  end

  test "the grouping switch drives the feed's show_objects_only_once filter", %{me: me} do
    Settings.put(NotificationPreferencesLive.display_setting_key(:group), true, current_user: me)

    on = conn(user: me, account: me.account) |> visit("/notifications") |> wait_async()
    assert live_assigns(on)[:feed_filters] |> e(:show_objects_only_once, nil) == true

    # and off again, which is the preset's own value
    Settings.put(NotificationPreferencesLive.display_setting_key(:group), false, current_user: me)

    off = conn(user: me, account: me.account) |> visit("/notifications") |> wait_async()
    assert live_assigns(off)[:feed_filters] |> e(:show_objects_only_once, nil) == false
  end
end
