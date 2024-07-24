defmodule Bonfire.Social.Feeds.Fediverse.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "show" do
    # test "not logged in" do
    #   conn = conn()
    #   conn = get(conn, "/feed/federation")
    #   doc = floki_response(conn) #|> debug()
    #   # assert redirected_to(conn) =~ "/login"
    #   assert [_] = Floki.find(doc, "<h1>Federation")
    # end

    test "with account" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(account: account)
      next = "/feed/federation"
      feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [_] = Floki.find(doc, "[id*='#{feed_id}']")
    end

    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/feed/federation"
      feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)

      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [_] = Floki.find(doc, "[id*='#{feed_id}']")
    end

    # test "remote posts in fediverse feed" do
    #   account = fake_account!()
    #   user = fake_user!(account) # TODO use remote actor
    #   attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

    #   assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")
    #   assert post.post_content.name =~ "test post name"

    #   conn = conn(user: user, account: account)
    #   next = "/feed/federation"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [feed] = Floki.find(doc, "#feed:federation")
    #   assert Floki.text(feed) =~ "test post name"
    # end

    # test "federated posts (which I am allowed to see) from people I am not following in fediverse feed" do
    #   user = fake_user!() # TODO with remote actor

    #   account = fake_account!()
    #   user2 = fake_user!(account)

    #   attrs = %{to_circles: [user2.id], post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

    #   assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: activity_pub")
    #   assert post.post_content.name =~ "test post name"

    #   conn = conn(user: user2, account: account)
    #   next = "/feed/federation"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [feed] = Floki.find(doc, "#feed:federation")
    #   assert Floki.text(feed) =~ "test post name"

    # end
  end

  describe "DO NOT show" do
    # test "not logged in: fallback to instance feed" do
    #   conn = conn()
    #   conn = get(conn, "/feed/federation")
    #   doc = floki_response(conn) #|> debug()
    #   # assert redirected_to(conn) =~ "/login"
    #   assert [_] = Floki.find(doc, "[id='feed:home']")
    # end

    test "local-only posts in fediverse feed" do
      account = fake_account!()
      user = fake_user!(account)

      account2 = fake_account!()
      user2 = fake_user!(account2)
      Follows.follow(user2, user)

      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "<p>epic html message</p>"
        }
      }

      assert {:ok, post} = Posts.publish(current_user: user, post_attrs: attrs, boundary: "local")
      assert post.post_content.name =~ "test post name"

      conn = conn(user: user2, account: account2)
      next = "/feed/federation"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [] = Floki.find(doc, "#feed:federation")
      # refute Floki.text(feed) =~ "test post name"
    end
  end
end
