defmodule Bonfire.Social.Notifications.Threads.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)
    {:ok, conn: conn}
  end

  describe "show" do
    # FIXME: should this be expected behaviour? (without @ mention)
    @tag :skip_ci
    test "replies I'm allowed to see (even from people I'm not following) in my notifications", %{conn: conn} do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      attrs = %{post_content: %{html_body: "<p>here is an epic html post</p>"}}

      assert {:ok, post} =
               Posts.publish(current_user: someone, post_attrs: attrs, boundary: "public")

      responder = fake_user!()

      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "<p>epic html reply</p>"},
        reply_to_id: post.id
      }

      assert {:ok, _post_reply} =
               Posts.publish(current_user: responder, post_attrs: attrs_reply, boundary: "public")

      conn(user: someone, account: some_account)
      |> visit("/notifications")
      |> assert_has(".feed", text: "epic html reply")
    end
  end

  describe "DO NOT show" do
    test "replies I'm NOT allowed to see in my notifications" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      attrs = %{post_content: %{html_body: "<p>here is an epic html post</p>"}}
      assert {:ok, post} = Posts.publish(current_user: someone, post_attrs: attrs)

      responder = fake_user!()

      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "epic html reply"},
        reply_to_id: post.id
      }

      assert {:ok, _post_reply} = Posts.publish(current_user: responder, post_attrs: attrs_reply)

      conn(user: someone, account: some_account)
      |> visit("/notifications")
      |> refute_has(".feed", text: "epic html reply")
    end
  end

    # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context
    test "As a user, when someone replies to my activity, I want to see it in notifications, including the author's name of the reply", %{conn: conn} do
      # Create users
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
      }
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"},
        reply_to_id: post.id
      }
      {:ok, post_reply} = Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications
      conn(user: alice, account: account)
      |> visit("/notifications")
      |> assert_has("[data-id=subject]", text: bob.profile.name)
    end

    test "As a user, when someone replies to my activity, I want to see it in notifications, include the replied message", %{conn: conn} do
      # Create users
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
      }
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
        reply_to_id: post.id
      }
      {:ok, post_reply} = Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications
      conn(user: alice, account: account)
      |> visit("/notifications")
      |> assert_has("article", text: "reply to first post")
    end

    test "As a user, when someone replies to my activity, I want to see it in notifications, included the author's name of the original activity"  do
      # Create users
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
      }
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
        reply_to_id: post.id
      }
      {:ok, post_reply} = Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications
      conn(user: alice, account: account)
      |> visit("/notifications")
      |> assert_has("article a", text: alice.profile.name)
    end

    test "As a user, when someone replies to my activity, I want to see it in notifications, included the content of the original activity", %{conn: conn} do
      # Create users
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Alice creates a post
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
      }
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Bob replies to Alice's post
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
        reply_to_id: post.id
      }
      {:ok, post_reply} = Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      # Alice checks her notifications
      conn(user: alice, account: account)
      |> visit("/notifications")
      |> assert_has("article", text: "first post")
    end

end
