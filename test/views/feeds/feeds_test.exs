defmodule Bonfire.Social.Feeds.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}

  test "replies that appear via pubsub should show the reply_to" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    Follows.follow(me, alice)
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

    # then alice creates a post
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    # reply_to = %{reply_to_id: post.id, thread_id: post.id}

    reply_content = "this is reply 112"

    attrs_reply = %{
      post_content: %{
        html_body: reply_content
      },
      reply_to_id: post.id
    }

    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")

    # im not sure if live_pubsub_wait is enough to wait for asyync loading of the reply
    # so we wait a bit more
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    live_pubsub_wait(view)
    #  open_browser(view)
    assert has_element?(view, "[data-id=feed]", reply_content)

    # view |> open_browser()
  end

  @tag :todo
  test "images/attachments should be hidden behind CW even when the initial activity appears via pubsub" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # then I log in and go to my local feed
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    # and create a post
    html_body = "epic html message"

    attrs = %{
      # uploaded_media: [], WIP: Not sure how to add a fake media
      post_content: %{html_body: html_body}
    }

    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
    {:ok, view, _html} = live(conn, "/feed/local")
    live_pubsub_wait(view)

    # TODO!

    # we wait a bit more
    # view |> open_browser()
  end

  describe "Feeds UX" do
    test "As a user when I publish a new post I want to see it appearing at the beginning of the feed without refreshing the page" do
    end

    test "As a user I want to see the activity boundary" do
    end

    test "As a user I want to see if I already boosted an activity" do
    end

    test "As a user I want to see if I already liked an activity" do
    end

    test "As a user I want to see the context a message is replying to" do
    end

    test "When I click the reply button, I want to navigate to the thread page" do
    end

    test "When I click the boost button, I want the boosted activity to appear in the timeline without refreshing" do
    end

    test "When I click the like button, I want to see the liked activity without refreshing" do
    end

    test "As a user I want to click over the user avatar or name and navigate to their own profile page" do
    end

    test "As a user I want to click over a user mention within an activity and navigate to their own profile page" do
    end

    test "As a user I want to click over a link that is part of an activity body and navigate to that link" do
    end
  end
end
