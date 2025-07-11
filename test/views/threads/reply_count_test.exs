defmodule Bonfire.Social.Threads.RepliesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
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
      post_content: %{summary: "summary", html_body: "<p>first post</p>"}
    }

    assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", html_body: "<p>reply to first post</p>"},
      reply_to_id: op.id
    }

    assert {:ok, post_reply} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    conn = conn(user: alice, account: account)

    conn
    |> visit("/post/#{op.id}")
    # |> PhoenixTest.open_browser()
    |> assert_has_or_open_browser("[data-id=reply_count]", text: "1")
  end
end
