defmodule Bonfire.Social.Feeds.Instance.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Boosts

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, user: me}
  end

  describe "show" do
    test "not logged in", %{user: user, account: account} do
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn()
      |> visit("/feed/local")
      |> assert_has("a", text: "Log in")
      |> assert_has("span", text: "Explore local activities")
    end

    test "with user", %{conn: conn, user: user, account: account} do
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn(user: user, account: account)
      |> visit("/feed/local")
      |> assert_has("span", text: "Explore local activities")
    end

    test "my own posts in instance feed (with local preset selected)", %{
      conn: conn,
      user: user,
      account: account
    } do
      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "local")
      assert post.post_content.name =~ "test post name"

      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn(user: user, account: account)
      |> visit("/feed/local")
      |> assert_has("[id*='#{feed_id}']", text: "summary")
    end

    test "local posts from people I am not following in instance feed (if local preset selected)",
         %{conn: conn, user: user, account: account} do
      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "local")
      assert post.post_content.name =~ "test post name"

      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn(user: user, account: account)
      |> visit("/feed/local")
      |> assert_has("[id*='#{feed_id}']", text: "summary")
    end
  end

  describe "DO NOT show" do
    test "posts I'm NOT allowed to see in instance feed", %{
      conn: conn,
      user: user,
      account: account
    } do
      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs)
      assert post.post_content.html_body =~ "epic html message"

      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      conn(user: user2, account: account2)
      |> visit("/feed/local")
      |> assert_has("[id*='#{feed_id}']")
      |> refute_has("[id*='#{feed_id}']", text: "epic html message")
    end
  end

  test "Logged-out Home activities feed shows the instance outbox filtered by public boundary", %{
    user: user,
    account: account
  } do
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    account3 = fake_account!()
    carl = fake_user!(account3)

    guest_attrs = %{
      post_content: %{html_body: "post with guest_attrs"}
    }

    local_attrs = %{
      post_content: %{html_body: "post with local_attrs"}
    }

    admin_attrs = %{
      post_content: %{html_body: "post with admin_attrs"}
    }

    total_posts = 3

    {:ok, public_post} =
      Posts.publish(current_user: alice, post_attrs: guest_attrs, boundary: "public")

    publish_multiple_times(local_attrs, bob, total_posts, "local")
    publish_multiple_times(admin_attrs, carl, total_posts, "admins")
    assert {:ok, boost} = Boosts.boost(alice, public_post)

    conn()
    |> visit("/feed/local")
    |> assert_has("article", count: 1)
  end
end
