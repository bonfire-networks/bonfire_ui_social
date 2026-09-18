defmodule Bonfire.UI.Social.NotificationChipsTest do
  @moduledoc """
  Category chips on the notifications feed.

  Each chip is a URL (`/notifications/<verb>`, with plural path aliases), declared in config,
  and a segment resolves against the verb registry so any declared verb works whether or not a
  chip is shown for it.
  """
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.UI.Social.NotificationFiltersLive

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    # the test default is 2, which would cut the oldest fixture off the unfiltered feed's first page
    Process.put([:bonfire, :default_pagination_limit], 10)

    me = fake_user!("chips_me")
    other = fake_user!("chips_other")

    {:ok, my_post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "my post that gets liked"}},
        boundary: "public"
      )

    {:ok, _like} = Likes.like(other, my_post)
    {:ok, _follow} = Follows.follow(other, me)

    {:ok, _mention} =
      Posts.publish(
        current_user: other,
        post_attrs: %{
          post_content: %{html_body: "hey @#{me.character.username} a mention for you"}
        },
        boundary: "public"
      )

    {:ok, conn: conn(user: me, account: me.account), me: me, other: other}
  end

  test "the unfiltered feed shows every notification and marks the Latest chip current", %{
    conn: conn
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-latest[aria-current=page]")
    |> assert_has("[data-verb=Like]")
    |> assert_has("[data-verb=Follow]")
    |> assert_has("[data-id=feed]", text: "a mention for you")
  end

  test "a chip path filters the feed to that verb and marks that chip current", %{conn: conn} do
    conn
    |> visit("/notifications/likes")
    |> wait_async()
    |> assert_has("#notification-filter-like[aria-current=page]")
    |> assert_has("[data-verb=Like]")
    |> refute_has("#notification-filter-latest[aria-current=page]")
    |> refute_has("[data-verb=Follow]")
  end

  test "chips link to their plural path, with the bare verb still resolving", %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-like[href='/notifications/likes']")

    conn
    |> visit("/notifications/like")
    |> wait_async()
    |> assert_has("#notification-filter-like[aria-current=page]")
    |> assert_has("[data-verb=Like]")
    |> refute_has("[data-verb=Follow]")
  end

  test "clicking a chip filters the already-loaded feed, and clicking Latest restores it", %{
    conn: conn
  } do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> click_link("#notification-filter-like", "Likes")
    |> wait_async()
    |> assert_path("/notifications/likes")
    |> assert_has("[data-verb=Like]")
    |> refute_has("[data-verb=Follow]")
    |> click_link("#notification-filter-latest", "Latest")
    |> wait_async()
    |> assert_path("/notifications")
    |> assert_has("[data-verb=Follow]")
  end

  test "a chip with no matching notifications says so, and going back restores the feed",
       %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    # nothing in the fixtures is a boost
    |> click_link("#notification-filter-boost", "Boosts")
    |> wait_async()
    # the notifications preset queries a 30-day window, so the answer names the window: the preset's "You have no notifications" would claim more than the query asked
    |> assert_has("[data-id=feed]", text: "That's all for the last")
    |> refute_has("[data-verb=Like]")
    |> click_link("#notification-filter-latest", "Latest")
    |> wait_async()
    |> assert_has("[data-verb=Like]")
    |> assert_has("[data-verb=Follow]")
  end

  test "a preset-backed chip is hidden from users the preset's own gate excludes", %{conn: conn} do
    conn
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("#notification-filter-like")
    |> refute_has("#notification-filter-flag")
  end

  test "a moderator sees the preset-backed chip, and it loads that preset's feed" do
    admin = fake_admin!(fake_account!())
    flagger = fake_user!("chips_flagger")

    {:ok, post} =
      Posts.publish(
        current_user: flagger,
        post_attrs: %{post_content: %{html_body: "something worth flagging"}},
        boundary: "public"
      )

    {:ok, _flag} = Bonfire.Social.Flags.flag(flagger, post)

    conn(user: admin, account: admin.account)
    |> visit("/notifications")
    |> wait_async()
    |> click_link("#notification-filter-flag", "Flagged")
    |> wait_async()
    |> assert_path("/notifications/flags")
    # the chip bar survives the preset switch, so the moderator can get back
    |> assert_has("#notification-filter-latest")
    |> assert_has("[data-id=feed]", text: "something worth flagging")
  end

  test "a declared verb resolves even with no chip shown for it", %{conn: conn} do
    conn
    |> visit("/notifications/follow")
    |> wait_async()
    |> assert_has("[data-verb=Follow]")
    |> refute_has("[data-verb=Like]")
  end

  test "a segment matching no verb redirects to the unfiltered feed", %{conn: conn} do
    conn
    |> visit("/notifications/not-a-verb")
    |> wait_async()
    |> assert_path("/notifications")
    |> assert_has("#notification-filter-latest[aria-current=page]")
    |> assert_has("[data-verb=Like]")
  end

  test "chips render from config, in config order, falling back to the key for the path" do
    Process.put(
      [:bonfire_social, Bonfire.Social.Notifications, :categories],
      latest: %{name_pluralized: "Everything", activity_types: []},
      like: %{name_pluralized: "Faves"}
    )

    doc =
      render_component(&NotificationFiltersLive.render/1, %{__context__: %{}})
      |> Floki.parse_document!()

    assert Floki.attribute(doc, "#notification-filters a", "href") == [
             "/notifications",
             "/notifications/like"
           ]

    assert Floki.find(doc, "#notification-filter-like") |> Floki.text() =~ "Faves"
    assert Floki.find(doc, "#notification-filter-latest") |> Floki.text() =~ "Everything"
    assert [] = Floki.find(doc, "#notification-filter-boost")
  end
end
