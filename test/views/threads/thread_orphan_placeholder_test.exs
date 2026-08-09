defmodule Bonfire.UI.Social.Threads.OrphanPlaceholderTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    account3 = fake_account!()
    charlie = fake_user!(account3)

    {:ok, op} =
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "<p>Original post</p>"}},
        boundary: "public"
      )

    # bob's reply is only visible to himself ("mentions" with nobody mentioned)
    {:ok, hidden_reply} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{
          post_content: %{html_body: "<p>hidden parent</p>"},
          reply_to_id: op.id
        },
        boundary: "mentions"
      )

    {:ok, public_child} =
      Posts.publish(
        current_user: bob,
        post_attrs: %{
          post_content: %{html_body: "<p>public child</p>"},
          reply_to_id: hidden_reply.id
        },
        boundary: "public"
      )

    {:ok,
     conn: conn(user: charlie, account: account3),
     bob_conn: conn(user: bob, account: account2),
     op: op,
     hidden_reply: hidden_reply,
     public_child: public_child}
  end

  test "a reply under a boundary-hidden parent still renders, under an unavailable placeholder",
       %{conn: conn, op: op} do
    conn
    |> visit("/discussion/#{op.id}")
    |> assert_has("[data-role='comment-unavailable']")
    |> assert_has("[data-id='comment']", text: "public child")
    |> refute_has("[data-id='comment']", text: "hidden parent")
  end

  test "positive control: the author of the hidden reply sees it without a placeholder",
       %{bob_conn: bob_conn, op: op} do
    bob_conn
    |> visit("/discussion/#{op.id}")
    |> refute_has("[data-role='comment-unavailable']")
    |> assert_has("[data-id='comment']", text: "hidden parent")
    |> assert_has("[data-id='comment']", text: "public child")
  end
end
