defmodule Bonfire.Social.Feeds.MyFeed.Test do

  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Boosts
  alias Bonfire.Common.Repo

  describe "show" do

    test "not logged in, display instance feed instead" do
      conn = conn()
      conn = get(conn, "/feed")
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, nil)
      assert redirected_to(conn) =~ "/login"

      # doc = floki_response(conn)
      # # main = Floki.find(doc, "main") |> IO.inspect
      # assert [] = Floki.find(doc, "[id='#{feed_id}']")

      # feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      # assert [_] = Floki.find(doc, "[id='#{feed_id}']")
    end


    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      {view, doc} = floki_live(conn, next) #|> IO.inspect
      assert [_] = Floki.find(doc, "[id='#{feed_id}']")
    end

    test "my own posts in my feed" do
      account = fake_account!()
      user = fake_user!(account)
      attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")
      assert post.post_content.name =~ "test post name"

      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      {view, doc} = floki_live(conn, next) #|> IO.inspect
      # debug(user: user)
      main = Floki.find(doc, "main") #|> debug()
      assert [feed] = Floki.find(doc, "[id='#{feed_id}']")
      assert Floki.text(feed) =~ "test post name"
    end

    test "posts I'm allowed to see in my feed" do
      account = fake_account!()
      user = fake_user!(account)

      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)

      attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")
      assert post.post_content.name =~ "test post name"

      conn = conn(user: user2, account: account2)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user2)

      {view, doc} = floki_live(conn, next) #|> IO.inspect
      # debug(user: user2)
      main = Floki.find(doc, "main") #|> debug()
      assert [feed] = Floki.find(doc, "[id='#{feed_id}']")
      assert Floki.text(feed) =~ "test post name"
    end

  end

  describe "DO NOT show" do

    test "with account only" do
      account = fake_account!()
      conn = conn(account: account) #|> dump
      next = "/feed"
      assert floki_redirect(conn, next) =~ "/switch-user"
      # {view, doc} = floki_live(conn, next)
      # main = Floki.find(doc, "main") #|> IO.inspect
      # assert [] = Floki.find(doc, "article")
    end

    test "posts from people I am not following in my feed" do
      user = fake_user!()
      attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")
      assert post.post_content.name =~ "test post name"

      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user)

      {view, doc} = floki_live(conn, next) #|> IO.inspect
      assert [feed] = Floki.find(doc, "[id='#{feed_id}']")
      refute Floki.text(feed) =~ "test post name"

    end

    test "posts I'm NOT allowed to see in my feed" do
      account = fake_account!()
      user = fake_user!(account)

      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)

      attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs)
      assert post.post_content.name =~ "test post name"

      conn = conn(user: user2, account: account2)
      next = "/feed"
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, user2)

      {view, doc} = floki_live(conn, next) #|> IO.inspect
      # main = Floki.find(doc, "main") |> IO.inspect
      assert [feed] = Floki.find(doc, "[id='#{feed_id}']")
      refute Floki.text(feed) =~ "test post name"
    end
  end


  test "Logged-in home activities feed shows the user inbox" do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    account3 = fake_account!()
    carl = fake_user!(account3)

    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    guest_attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    local_attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    admin_attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    {:ok, post0} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    # bob follows alice
    Follows.follow(bob, alice)

    total_posts = 3
    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    publish_multiple_times(local_attrs, bob, total_posts, "local")
    publish_multiple_times(admin_attrs, carl, total_posts, "admins")
    assert {:ok, boost} = Boosts.boost(alice, post)

    conn = conn(user: bob, account: account)
    next = "/feed"
    {view, doc} = floki_live(conn, next)
    assert doc
      |> Floki.find("article")
      |> length == 7
  end


end
