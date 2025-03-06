defmodule Bonfire.Social.Notifications.Threads.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes

  setup do
    alice = fake_user!("alice")
    bob = fake_user!("bob")
    carl = fake_user!("carl")

    conn_alice = conn(user: alice)
    conn_bob = conn(user: bob)
    conn_carl = conn(user: carl)

    {:ok,
     %{
       alice: alice,
       bob: bob,
       carl: carl,
       conn_alice: conn_alice,
       conn_bob: conn_bob
       # conn_carl: conn_carl
     }}
  end

  describe "DO NOT show" do
    test "replies I'm NOT allowed to see in my notifications", %{
      bob: bob,
      carl: carl,
      conn_bob: conn_bob
    } do
      # Bob creates a post (private by default)
      attrs = %{post_content: %{html_body: "here is an epic html post"}}
      assert {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs)

      # Carl replies to Bob's post (private by default)
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "epic html reply"},
        reply_to_id: post.id
      }

      assert {:ok, _post_reply} = Posts.publish(current_user: carl, post_attrs: attrs_reply)

      # Bob checks notifications
      conn_bob
      |> visit("/notifications")
      |> refute_has("article", text: "epic html reply")
    end
  end

  # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context

  test "As a user, when someone replies to my activity, I want to see it in notifications, included the author's name, and the content of the original activity",
       %{alice: alice, bob: bob, conn_alice: conn_alice} do
    # Alice creates a post
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "alice's first post"}
    }

    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Bob replies to Alice's post, incl @ mention
    attrs_reply = %{
      post_content: %{
        summary: "summary",
        name: "name 2",
        html_body: "@alice bob's reply to the post"
      },
      reply_to_id: post.id
    }

    {:ok, _post_reply} =
      Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    # Alice checks her notifications
    conn_alice
    |> visit("/notifications")
    |> assert_has("article", text: attrs_reply.post_content.html_body)
    |> assert_has("[data-id=subject]", text: bob.profile.name)
    |> assert_has("[data-verb=Reply]")
    |> assert_has("article", text: attrs.post_content.html_body)
  end
end
