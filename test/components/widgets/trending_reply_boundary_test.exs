defmodule Bonfire.UI.Social.WidgetTrendingReplyBoundaryTest do
  @moduledoc """
  Repro: clicking Reply on an activity in the dashboard "Top discussions"
  widget should carry the post's boundary (e.g. "local") into the composer's
  `to_boundaries`, same as clicking Reply in a regular feed.

  The sticky-composer delivery (PersistentLive presence lookup) doesn't run in
  the LiveViewTest harness, so instead of asserting on the composer DOM we
  intercept the assigns the reply handler sends to the composer.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)
    other = fake_user!()

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: other,
        post_attrs: %{post_content: %{html_body: "trending boundary post"}},
        boundary: "local"
      )

    # capture what the reply handler sends to the composer; `mode: :shared` because
    # the handler runs in the LiveView process, not the test process
    test_pid = self()

    Repatch.patch(
      Bonfire.UI.Common.SmartInput.LiveHandler,
      :open_with_text_suggestion,
      [mode: :shared],
      fn _text, set_assigns, _socket ->
        send(test_pid, {:composer_opened, Map.new(set_assigns)})
        :ok
      end
    )

    conn = conn(user: me, account: account)

    {:ok, conn: conn, me: me, other: other, post: post}
  end

  defp boundary_slugs(assigns) do
    (assigns[:to_boundaries] || [])
    |> List.wrap()
    |> Enum.map(fn
      {slug, _name} -> slug
      slug -> slug
    end)
  end

  test "reply from a FEED to a post published in a group carries the group context boundary (control)",
       %{conn: conn, other: other} do
    group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "reply boundary group"})

    group_post =
      Bonfire.Classify.Simulate.fake_post_in_group!(
        other,
        group,
        "<p>group trending post</p>"
      )

    {:ok, view, _html} = live(conn, "/feed/local")

    assert render(view) =~ "group trending post"

    Process.sleep(1000)
    render(view)

    view
    |> element("[data-id=action_reply][phx-value-id='#{id(group_post)}']")
    |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert [{:clone_context, _}] = assigns[:to_boundaries],
           "expected clone_context boundary, got: #{inspect(assigns[:to_boundaries])}"
  end

  test "reply from the WIDGET to a post published in a group carries the group context boundary",
       %{conn: conn, other: other} do
    group = Bonfire.Classify.Simulate.fake_group!(other, %{name: "reply boundary group"})

    group_post =
      Bonfire.Classify.Simulate.fake_post_in_group!(
        other,
        group,
        "<p>group trending post</p>"
      )

    {:ok, view, _html} = live(conn, "/dashboard")

    assert render(view) =~ "group trending post"

    Process.sleep(1000)
    render(view)

    view
    |> element("[data-id=action_reply][phx-value-id='#{id(group_post)}']")
    |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert [{:clone_context, _}] = assigns[:to_boundaries],
           "expected clone_context boundary, got: #{inspect(assigns[:to_boundaries])}"
  end

  test "reply from a regular feed carries the post's boundary into the composer (control)",
       %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, "/feed/local")

    assert render(view) =~ "trending boundary post"

    # let async (:async_actions-mode) update_many preloads land, as they would in dev
    Process.sleep(1000)
    render(view)

    view
    |> element("[data-id=action_reply]")
    |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert assigns[:reply_to_id] == id(post)

    assert "local" in boundary_slugs(assigns),
           "expected local boundary in composer, got: #{inspect(assigns[:to_boundaries])}"
  end

  test "reply from the trending discussions widget carries the post's boundary into the composer",
       %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, "/dashboard")

    assert render(view) =~ "trending boundary post"

    # let async (:async_actions-mode) update_many preloads land, as they would in dev
    Process.sleep(1000)
    render(view)

    view
    |> element("[data-id=action_reply]")
    |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert assigns[:reply_to_id] == id(post)

    assert "local" in boundary_slugs(assigns),
           "expected local boundary in composer, got: #{inspect(assigns[:to_boundaries])}"
  end
end
