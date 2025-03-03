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
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    account3 = fake_account!()
    carl = fake_user!(account3)

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

    {:ok, post0} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    # bob follows alice
    Follows.follow(alice, bob)

    # total_posts = 3
    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    {:ok, post1} = Posts.publish(current_user: bob, post_attrs: local_attrs, boundary: "local")
    {:ok, post2} = Posts.publish(current_user: carl, post_attrs: admin_attrs, boundary: "admins")

    assert {:ok, boost} = Boosts.boost(alice, post)

    conn(user: bob, account: account)
    |> visit("/feed")
    |> assert_has("article", count: 2)
  end
end
