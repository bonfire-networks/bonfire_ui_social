defmodule Bonfire.Social.UI.Feeds.MyFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Boosts
  use Mneme
  import Phoenix.LiveViewTest

  @moduletag :mneme

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, user: me}
  end

  describe "show" do
    test "not logged in, display instance feed instead", %{
      conn: conn,
      user: user,
      account: account
    } do
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn()
      |> visit("/feed")
      |> assert_has("[id*='#{feed_id}']")
    end

    test "account only, display instance feed instead", %{
      conn: conn,
      user: user,
      account: account
    } do
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn(account: account)
      |> visit("/feed")
      |> assert_has("[id*='#{feed_id}']")
    end

    test "with user", %{conn: conn, user: user, account: account} do
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      conn
      |> visit("/feed")
      |> assert_has("[id*='#{feed_id}']")
    end

    test "my own posts in my feed", %{conn: conn, user: user, account: account} do
      attrs = %{
        post_content: %{
          html_body: "epic html message"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      conn
      |> visit("/feed")
      |> assert_has("[id*='#{feed_id}']", text: "epic html message")
    end

    test "posts I'm allowed to see in my feed", %{conn: conn, user: user, account: account} do
      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)
      Follows.follow(user, user2)

      attrs = %{
        post_content: %{
          html_body: "epic html message"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      conn(user: user2, account: account2)
      |> visit("/feed/local")
      |> assert_has("article", text: "epic html message")
    end
  end

  describe "DO NOT show" do
    # FIXME
    test "posts from people I am not following in my feed", %{
      conn: conn,
      user: user,
      account: account
    } do
      user = fake_user!()

      attrs = %{
        post_content: %{
          html_body: "epic html message"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      conn
      |> visit("/feed")
      # |> assert_has("[id*='#{feed_id}']")
      |> refute_has("article", text: "epic html message")
    end

    test "posts I'm NOT allowed to see in my feed", %{conn: conn, user: user, account: account} do
      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)

      attrs = %{
        post_content: %{
          html_body: "epic html message"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs)
      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user2)

      conn(user: user2, account: account2)
      |> visit("/feed")
      |> assert_has("[id*='#{feed_id}']")
      |> refute_has("article", text: "epic html message")
    end
  end

  test "Logged-in home activities feed shows the user inbox", %{
    conn: conn,
    user: user,
    account: account
  } do
    # Create test users across different accounts
    # User in the same account as the test user
    alice = fake_user!(account)
    account2 = fake_account!()
    # User in a different account
    bob = fake_user!(account2)
    account3 = fake_account!()
    # User in yet another account
    carl = fake_user!(account3)

    # Define post content attributes 
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "public post"}
    }

    guest_attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "guest_attrs post"}
    }

    local_attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "local_attrs post"}
    }

    admin_attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "admin_attrs post"}
    }

    # Create an initial public post from Alice
    {:ok, post0} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Set up bob to follow alice - this is important for feed visibility
    Follows.follow(bob, alice)

    # Create posts with different visibility boundaries
    # Alice creates a public post (visible to everyone)
    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    {:ok, post3} = Posts.publish(current_user: alice, post_attrs: admin_attrs, boundary: "admins")
    # Bob creates a local post (visible only to users in the same instance)
    {:ok, post1} = Posts.publish(current_user: bob, post_attrs: local_attrs, boundary: "local")
    # Carl creates an admin post (visible only to admins)
    {:ok, post2} = Posts.publish(current_user: carl, post_attrs: guest_attrs, boundary: "public")

    # Alice boosts the public post
    # assert {:ok, boost} = Boosts.boost(alice, post)

    # Visit bob's feed and assert stuff
    conn(user: bob, account: account)
    |> visit("/feed/my")
    # |> PhoenixTest.open_browser()
    # |> assert_has("article", text: attrs.post_content.html_body)
    |> assert_has("article", text: local_attrs.post_content.html_body)
    |> refute_has("article", text: admin_attrs.post_content.html_body)
    |> refute_has("article", text: guest_attrs.post_content.html_body)

    # |> assert_has("article", count: 2)
  end
end
