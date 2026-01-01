defmodule Bonfire.UI.Social.Feeds.Notifications.ReplyTest do
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  setup do
    alice = fake_user!("alice")
    bob = fake_user!("bob")

    conn_alice = conn(user: alice)

    {:ok, %{alice: alice, bob: bob, conn_alice: conn_alice}}
  end

  # When an activity is a reply to another one, in the feed I want to see both activities:
  # the original activity and the reply with enough information to understand the context

  describe "reply notifications" do
    test "show the author's name of the reply", %{alice: alice, bob: bob, conn_alice: conn_alice} do
      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", html_body: "first post"}
      }

      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post (with @ mention to trigger notification)
      attrs_reply = %{
        post_content: %{summary: "summary", html_body: "@alice reply to first post"},
        reply_to_id: post.id
      }

      {:ok, _post_reply} =
        Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications
      conn_alice
      |> visit("/notifications")
      |> assert_has("[data-role=subject]", text: bob.profile.name)
    end

    test "show the replied message", %{alice: alice, bob: bob, conn_alice: conn_alice} do
      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", html_body: "first post"}
      }

      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post (with @ mention to trigger notification)
      attrs_reply = %{
        post_content: %{summary: "summary", html_body: "@alice reply to first post"},
        reply_to_id: post.id
      }

      {:ok, _post_reply} =
        Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications - should see the reply content
      conn_alice
      |> visit("/notifications")
      |> assert_has("article", text: "reply to first post")
    end

    test "show the reply verb indicator", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", html_body: "first post"}
      }

      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post (with @ mention to trigger notification)
      attrs_reply = %{
        post_content: %{summary: "summary", html_body: "@alice reply to first post"},
        reply_to_id: post.id
      }

      {:ok, _post_reply} =
        Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications - should see the Reply verb indicator
      conn_alice
      |> visit("/notifications")
      |> assert_has("[data-verb=Reply]")
    end
  end
end
