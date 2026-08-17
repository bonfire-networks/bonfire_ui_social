defmodule Bonfire.UI.Social.PullToRefreshTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Social.Markers
  alias Bonfire.Posts

  import Phoenix.LiveViewTest, only: [with_target: 2, render_click: 3, render: 1]

  setup do
    me = fake_user!("refresher")
    conn = conn(user: me)

    {:ok, conn: conn, me: me}
  end

  test "the feed root advertises the pull-to-refresh event", %{conn: conn} do
    conn
    |> visit("/feed/local")
    |> assert_has("[data-ptr-refresh=refresh]")
  end

  test "a thread root advertises its reset event", %{conn: conn, me: me} do
    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Thread root"}},
        boundary: "public"
      )

    conn
    |> visit("/post/#{post.id}")
    |> assert_has("[data-ptr-refresh=set]")
  end

  test "pushing refresh reloads the feed and forgets the saved reading position", %{
    conn: conn,
    me: me
  } do
    {:ok, _} =
      Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "Freshly refreshed content"}},
        boundary: "public"
      )

    # a saved position that an explicit "show me the newest" must forget
    Markers.save_reading_position(me, :my, Needle.ULID.generate())
    assert Markers.get_reading_position(me, "my")

    conn
    |> visit("/feed")
    |> unwrap(fn view ->
      # target the main timeline's FeedLive root (sidebar widget feeds also
      # carry the attribute, but only the page's own timeline tracks markers)
      [id | _] =
        render(view)
        |> Floki.parse_document!()
        |> Floki.find("#main-content [data-ptr-refresh=refresh]")
        |> Floki.attribute("id")

      view
      |> with_target("##{id}")
      |> render_click("refresh", %{})
    end)
    |> assert_has("[data-id=object_body]", text: "Freshly refreshed content", timeout: 3000)

    refute Markers.get_reading_position(me, "my")
  end
end
