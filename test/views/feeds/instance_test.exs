defmodule Bonfire.Social.Feeds.Instance.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Boosts

  describe "show" do
    test "not logged in" do
      conn = conn()
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      {:ok, _view, html} = live(conn, "/feed/local")
      # live_pubsub_wait(view)
      # open_browser(view)
      assert html =~ "Log in"

      # doc = floki_response(conn)
      # # |> IO.inspect
      # main = Floki.find(doc, "main")
      # # assert redirected_to(conn) =~ "/login"
      # assert [_] = Floki.find(doc, "[id='#{feed_id}']")
    end

    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      # |> IO.inspect
      {:ok, _view, html} = live(conn, "/feed/local")
      assert [_] = Floki.find(html, "[id*='#{feed_id}']")
    end

    test "my own posts in instance feed (with local preset selected)" do
      account = fake_account!()
      user = fake_user!(account)

      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "local")
      assert post.post_content.name =~ "test post name"

      conn = conn(user: user, account: account)
      next = "/feed/local"
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      assert Floki.text(feed) =~ "summary"
    end

    test "local posts from people I am not following in instance feed (if local preset selected)" do
      user = fake_user!()

      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "local")
      assert post.post_content.name =~ "test post name"

      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed/local"
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      # open_browser(view)
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      assert Floki.text(feed) =~ "summary"
    end
  end

  describe "DO NOT show" do
    test "posts I'm NOT allowed to see in instance feed" do
      account = fake_account!()
      user = fake_user!(account)

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

      conn = conn(user: user2, account: account2)
      next = "/feed/local"
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      refute Floki.text(feed) =~ "epic html message"
    end
  end

  test "Logged-out Home activities feed shows the instance outbox filtered by public boundary" do
    account = fake_account!()
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

    next = "/feed/local"
    conn = conn()
    {view, doc} = floki_live(conn, next)

    entries =
      doc
      |> Floki.find("article")

    # open_browser(view)
    dump(entries, "entries")
    assert length(entries) == 1
  end
end
