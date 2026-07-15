defmodule Bonfire.UI.Social.Feeds.A11y.Test do
  @moduledoc """
  Regression tests for feed-view accessibility fixes (2026-07):
  keyboard-focusable activities, labelled icon-only controls, and
  state-reflecting accessible names. See the feed-view audit for context.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui
  alias Bonfire.Posts
  alias Bonfire.Social.Boosts

  setup do
    me = fake_user!("meee")
    alice = fake_user!("alice")
    conn = conn(user: me)
    {:ok, conn: conn, alice: alice, me: me}
  end

  test "feed activities are keyboard-focusable with a visible focus ring", %{
    conn: conn,
    alice: alice
  } do
    {:ok, _post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "a focusable activity"}},
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> assert_has_or_open_browser("[data-id=object_body]", text: "a focusable activity")
    # the `focus-ring` utility gives the (tabindex=0) article a visible keyboard focus outline
    |> assert_has("[data-id=activity].focus-ring")
  end

  test "the customize-feeds gear is an icon-only link with an accessible name", %{conn: conn} do
    conn
    |> visit("/feed/local")
    |> assert_has("a[aria-label='Customize feeds']")
  end

  test "sidebar widget titles are exposed as headings", %{conn: conn, alice: alice} do
    {:ok, _post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "widgets render alongside me"}},
        boundary: "public"
      )

    conn
    |> visit("/feed/local")
    |> assert_has_or_open_browser("[data-id=object_body]", text: "widgets render alongside me")
    # WidgetBlockLive titles ("Customize this feed", "Trending", ...) must be headings, not bare divs
    |> assert_has("[role=heading][aria-level='2']")
  end

  test "a boosted activity reflects the boost state in the trigger's accessible name", %{
    conn: conn,
    alice: alice,
    me: me
  } do
    {:ok, post} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "boost me"}},
        boundary: "public"
      )

    {:ok, _} = Boosts.boost(me, post)

    conn
    |> visit("/feed/local")
    |> assert_has_or_open_browser("[data-id=object_body]", text: "boost me")
    # collapsed boost trigger must announce the boosted state (not convey it by colour alone)
    |> assert_has("[aria-label^='Boosted']")
  end
end
