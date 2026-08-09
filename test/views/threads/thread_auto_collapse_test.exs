defmodule Bonfire.UI.Social.Threads.AutoCollapseTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  # collapse policy under test: threads with >= 10 replies fold branches that have >= 3 nested replies

  setup do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    {:ok, op} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "<p>Original post</p>"}},
        boundary: "public"
      )

    {:ok, conn: conn(user: bob, account: account2), alice: alice, bob: bob, op: op}
  end

  defp publish_reply(user, reply_to_id, body) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{
          post_content: %{html_body: "<p>#{body}</p>"},
          reply_to_id: reply_to_id
        },
        boundary: "public"
      )

    post
  end

  defp publish_heavy_branch(alice, op) do
    # a branch with 3 nested replies (chain under r1), plus filler to push the thread total to >= 10
    r1 = publish_reply(alice, op.id, "branch root")
    r2 = publish_reply(alice, r1.id, "branch nested 1")
    r3 = publish_reply(alice, r2.id, "branch nested 2")
    _r4 = publish_reply(alice, r3.id, "branch nested 3")

    for n <- 1..9, do: publish_reply(alice, op.id, "filler #{n}")

    {r1, r3}
  end

  test "small threads stay fully expanded", %{conn: conn, alice: alice, op: op} do
    r1 = publish_reply(alice, op.id, "reply 1")
    r2 = publish_reply(alice, r1.id, "nested 1")
    _r3 = publish_reply(alice, r2.id, "nested 2")

    conn
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='comment']", count: 3)
    |> refute_has("[data-id='expand_collapsed_replies']")
    |> refute_has("[data-id='show_replies'][style*='display: none']")
  end

  test "in a large thread, a heavy branch starts collapsed behind a summary row", %{
    conn: conn,
    alice: alice,
    op: op
  } do
    {_r1, _r3} = publish_heavy_branch(alice, op)

    conn
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-id='expand_collapsed_replies']", count: 1)
    |> assert_has("[data-id='expand_collapsed_replies']", text: "3 replies")
    |> assert_has("[data-id='show_replies'][style*='display: none']", count: 1)
  end

  test "a branch containing the permalinked reply is not collapsed", %{
    conn: conn,
    alice: alice,
    op: op
  } do
    {_r1, r3} = publish_heavy_branch(alice, op)

    conn
    |> visit("/discussion/#{op.id}/reply/#{r3.id}")
    |> refute_has("[data-id='expand_collapsed_replies']")
    |> assert_has("[data-id='comment']", text: "branch nested 2")
  end

  test "guests see everything expanded (expansion needs a connected LiveView)", %{
    alice: alice,
    op: op
  } do
    publish_heavy_branch(alice, op)

    conn()
    |> visit("/discussion/#{op.id}")
    |> refute_has("[data-id='expand_collapsed_replies']")
    |> refute_has("[data-id='show_replies'][style*='display: none']")
  end
end
