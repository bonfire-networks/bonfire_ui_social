defmodule Bonfire.Social.UI.Feeds.RemoteFeed.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "show" do
    test "not logged in" do
      conn = conn()
      conn = get(conn, "/feed/remote")
      assert redirected_to(conn) =~ "/login"
      # doc = floki_response(conn) #|> debug()
      # assert [_] = Floki.find(doc, "<h1>Federation")
    end

    test "fediverse feed is accessible when logged in" do
      # Setup user account
      account = fake_account!()
      user = fake_user!(account)
      feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)

      # Visit the fediverse feed as the user and verify it's visible
      conn(user: user, account: account)
      |> visit("/feed/remote")
      |> assert_has("[id*='#{feed_id}']")
    end

    test "federated posts (which I am allowed to see) from people I am not following in fediverse feed" do
      # Setup users
      account = fake_account!()
      local_user = fake_user!(account)

      {post, _} = Fake.create_test_content(:remote, nil, nil)

      # Check local_user can see the post in remote feed
      conn(user: local_user, account: account)
      |> visit("/feed/remote")
      |> assert_has("article", text: "content from fediverse")
    end
  end

  describe "DO NOT show" do
    # test "not logged in: fallback to instance feed" do
    #   conn = conn()
    #   conn = get(conn, "/feed/remote")
    #   doc = floki_response(conn) #|> debug()
    #   # assert redirected_to(conn) =~ "/login"
    #   assert [_] = Floki.find(doc, "[id='feed:home']")
    # end

    test "local posts are not visible in fediverse feed" do
      # Setup users and follow relationship
      account = fake_account!()
      user = fake_user!(account)

      # Create a local-only post
      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test local post name",
          html_body: "<p>epic html message</p>"
        }
      }

      # feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)
      # |> IO.inspect(label: "feeeee")

      assert {:ok, post} =
               Posts.publish(current_user: user, post_attrs: attrs, boundary: "public")

      assert post.post_content.name =~ "local post name"

      conn(user: user, account: account)
      |> visit("/feed/explore")
      |> assert_has("article", text: "local post name")

      # Visit the fediverse feed and verify post is not visible
      conn(user: user, account: account)
      |> visit("/feed/remote")
      |> refute_has("article", text: "local post name")
    end
  end
end
