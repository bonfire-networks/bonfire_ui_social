defmodule Bonfire.UI.Social.Feeds.Notifications.ReplyTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context
  test "As a user, when someone replies to my activity, I want to see it in notifications, including the author' name of the reply" do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    # Follows.follow(alice, bob)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
    }

    # {:ok, post} =        Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"},
      reply_to_id: post.id
    }

    # |> IO.inspect
    assert {:ok, post_reply} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: alice)

    fp =
      feed.edges
      |> List.first()

    # |> IO.inspect

    assigns = [activity: fp.activity, showing_within: :notifications]
    assert doc = render_stateful(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
           |> Floki.parse_fragment()
           ~> elem(1)
           |> Floki.find("[data-id=subject]")
           |> Floki.text() =~ bob.profile.name
  end

  test "As a user, when someone replies to my activity, I want to see it in notifications, include the replied message" do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    # Follows.follow(alice, bob)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
    }

    assert {:ok, post} = Posts.publish(alice, attrs, "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
      reply_to_id: post.id
    }

    # |> IO.inspect
    assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public")

    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: alice)

    fp =
      feed.edges
      # |> debug()
      |> List.first()

    assigns = [activity: fp.activity, showing_within: :notifications]
    assert doc = render_stateful(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
           |> Floki.parse_fragment()
           ~> elem(1)
           # |> debug()
           |> Floki.find("div.reply_message")
           |> Floki.text() =~ "reply to first post"
  end

  test "As a user, when someone replies to my activity, I want to see it in notifications, included the author's name of the original activity" do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    # Follows.follow(alice, bob)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
    }

    assert {:ok, post} = Posts.publish(alice, attrs, "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
      reply_to_id: post.id
    }

    # |> IO.inspect
    assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public")

    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: alice)

    fp =
      feed.edges
      # |> debug()
      |> List.first()

    assigns = [activity: fp.activity, showing_within: :notifications]
    assert doc = render_stateful(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
           |> Floki.parse_fragment()
           ~> elem(1)
           # |> debug()
           |> Floki.find("div.main_reply_to a")
           |> Floki.text() =~ alice.profile.name
  end

  test "As a user, when someone replies to my activity, I want to see it in notifications, included the content of the original activity" do
    account = fake_account!()
    alice = fake_user!(account)

    account2 = fake_account!()
    bob = fake_user!(account2)

    # Follows.follow(alice, bob)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}
    }

    assert {:ok, post} = Posts.publish(alice, attrs, "public")

    # Reply to the original post
    attrs_reply = %{
      post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"},
      reply_to_id: post.id
    }

    # |> IO.inspect
    assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public")

    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: alice)

    fp =
      feed.edges
      # |> debug()
      |> List.first()

    assigns = [activity: fp.activity, showing_within: :notifications]
    assert doc = render_stateful(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
           |> Floki.parse_fragment()
           ~> elem(1)
           # |> debug()
           |> Floki.find("div.reply_to")
           |> Floki.text() =~ "first post"
  end
end
