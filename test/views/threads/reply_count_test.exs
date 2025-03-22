defmodule Bonfire.Social.Threads.RepliesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  # when we enable counts
  test "As a user I want to see the activity total replies" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)
    # Create bob user
    account2 = fake_account!()
    bob = fake_user!(account2)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
    }

    assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"},
      reply_to_id: op.id
    }

    assert {:ok, post_reply} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    # bob follows alice
    Follows.follow(bob, alice)

    conn = conn(user: bob, account: account2)
    next = "/feed"
    {view, _doc} = floki_live(conn, next)

    # wait for async
    live_async_wait(view)

    assert view
           |> render()
           # |> info
           |> Floki.find("[data-id=feed] article")
           |> List.last()
           |> Floki.text() =~ "Reply"
  end
end
