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

  test "refreshing a deep DM permalink keeps readable ancestors and hides them from outsiders" do
    account = fake_account!()
    sender = fake_user!(account)
    recipient = fake_user!(fake_account!())
    outsider = fake_user!(fake_account!())
    Process.put([:bonfire, :thread_pagination_hard_limit], 2)
    Process.put([:bonfire, :thread_default_root_reply_limit], 2)

    {:ok, root} = Bonfire.Messages.send(sender, %{post_content: %{html_body: "Private conversation"}}, recipient)

    messages = Enum.scan(1..6, root, fn n, parent ->
      {:ok, message} = Bonfire.Messages.send(sender, %{
        post_content: %{html_body: "Private reply #{n}"},
        reply_to_id: parent.id
      }, recipient)
      message
    end)

    target = List.last(messages)
    url = "/discussion/#{root.id}/reply/6/#{target.id}"

    session = conn(user: sender, account: account) |> visit(url)
    session = Enum.reduce(1..6, session, fn n, session -> assert_has(session, "[data-id='comment']", text: "Private reply #{n}") end)

    session
    |> visit(url)
    |> refute_has("[data-role='comment-unavailable']")
    |> assert_has("[data-id='comment']", text: "Private reply 1")
    |> assert_has("[data-id='comment']", text: "Private reply 6")

    assert %{edges: []} = Bonfire.Social.Threads.list_replies(root.id,
      current_user: outsider,
      total_replies_count: 6,
      include_path_ids: Bonfire.Social.Threads.thread_ancestors_path(target.id)
    )
  end
end
