defmodule Bonfire.UI.Social.ReplyMentionTest do
  @moduledoc """
  Replying should pre-fill the composer with an `@mention` of the author being replied to.

  Regression: the feed passes `participants={e(entry, :participants, [])}` to every activity,
  and `[]` is truthy in Elixir, so the `||` fallback that looks up the thread participants
  never ran for feed replies — the composer opened with no mention at all.

  The sticky-composer delivery (PersistentLive presence lookup) doesn't run in the
  LiveViewTest harness, so we intercept the assigns the reply handler sends to the composer.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  setup do
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)

    account = fake_account!()
    me = fake_user!(account)
    other = fake_user!()

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: other,
        post_attrs: %{post_content: %{html_body: "reply mention test post"}},
        boundary: "local"
      )

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

    {:ok, conn: conn, account: account, me: me, other: other, post: post}
  end

  test "replying from a feed pre-fills a mention of the author", %{conn: conn, other: other} do
    {:ok, view, _html} = live(conn, "/feed/local")
    assert render(view) =~ "reply mention test post"

    view |> element("[data-id=action_reply]") |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert assigns[:mention_text] =~ "@#{other.character.username}",
           "expected the author to be mentioned, got: #{inspect(assigns[:mention_text])}"
  end

  test "replying from a thread page pre-fills a mention of the author", %{
    conn: conn,
    other: other,
    post: post
  } do
    {:ok, view, _html} = live(conn, "/post/#{id(post)}")
    assert render(view) =~ "reply mention test post"

    view |> element("[data-id=action_reply]") |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert assigns[:mention_text] =~ "@#{other.character.username}",
           "expected the author to be mentioned, got: #{inspect(assigns[:mention_text])}"
  end

  test "replying to my own post does not mention myself", %{conn: conn, me: me} do
    {:ok, mine} =
      Bonfire.Posts.publish(
        current_user: me,
        post_attrs: %{post_content: %{html_body: "my own post to reply to"}},
        boundary: "local"
      )

    {:ok, view, _html} = live(conn, "/post/#{id(mine)}")

    view |> element("[data-id=action_reply]") |> render_click()

    assert_receive {:composer_opened, assigns}, 2000

    assert is_nil(assigns[:mention_text]),
           "expected no self-mention, got: #{inspect(assigns[:mention_text])}"
  end
end
