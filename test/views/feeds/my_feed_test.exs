defmodule Bonfire.Social.UI.Feeds.MyFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Boosts
  use Mneme
  import Phoenix.LiveViewTest

  @moduletag :mneme

  describe "show" do
    test "not logged in, display instance feed instead" do
      conn = conn()
      {view, doc} = floki_live(conn, "/feed")
      # assert redirected_to(conn) =~ "/login"

      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      assert [_] = Floki.find(doc, "[id*='#{feed_id}']")
    end

    test "account only, display instance feed instead" do
      account = fake_account!()
      # |> debug
      conn = conn(account: account)
      {view, doc} = floki_live(conn, "/feed")
      # assert redirected_to(conn) =~ "/login"

      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      assert [_] = Floki.find(doc, "[id*='#{feed_id}']")
    end

    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [_] = Floki.find(doc, "[id*='#{feed_id}']")
    end

    test "my own posts in my feed" do
      account = fake_account!()
      user = fake_user!(account)

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      # debug(user: user)
      # |> debug()
      main = Floki.find(doc, "main")
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      assert Floki.text(feed) =~ attrs[:post_content][:html_body]
    end

    test "posts I'm allowed to see in my feed" do
      account = fake_account!()
      user = fake_user!(account)

      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)
      Follows.follow(user, user2)

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      conn = conn(user: user2, account: account2)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user2)
      # {view, doc} = floki_live(conn, next)
      # debug(user: user2)
      {:ok, view, html} = live(conn, "/feed/local")
      # |> debug()
      main = Floki.find(html, "main")
      # open_browser(view)

      auto_assert true <-
                    html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ attrs[:post_content][:html_body]

      # assert [feed] = Floki.find(html, "[id*='#{feed_id}']")
      # open_browser(view)
      # assert Floki.text(feed) =~ attrs[:post_content][:html_body]
    end
  end

  describe "DO NOT show" do
    # test "with account only" do
    #   account = fake_account!()
    #   # |> debug
    #   conn = conn(account: account)
    #   next = "/feed"
    #   assert floki_redirect(conn, next) =~ "/switch-user"

    #   # {view, doc} = floki_live(conn, next)
    #   # main = Floki.find(doc, "main") #|> IO.inspect
    #   # assert [] = Floki.find(doc, "article")
    # end

    test "posts from people I am not following in my feed" do
      user = fake_user!()

      attrs = %{
        post_content: %{
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.html_body =~ attrs[:post_content][:html_body]

      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      refute Floki.text(feed) =~ attrs[:post_content][:html_body]
    end

    test "posts I'm NOT allowed to see in my feed" do
      account = fake_account!()
      user = fake_user!(account)

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

      conn = conn(user: user2, account: account2)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user2)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      # main = Floki.find(doc, "main") |> IO.inspect
      assert [feed] = Floki.find(doc, "[id*='#{feed_id}']")
      refute Floki.text(feed) =~ "epic html message"
    end
  end

  test "Logged-in home activities feed shows the user inbox" do
    account = fake_account!()
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

    conn = conn(user: bob, account: account)
    next = "/feed"
    {:ok, view, html} = live(conn, next)
    Phoenix.LiveViewTest.open_browser(view)

    assert 2 ==
             html
             |> Floki.find("article")
             |> length()
  end
end
