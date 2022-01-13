defmodule Bonfire.UI.Social.Feeds.Notifications.ReplyTest do

  use Bonfire.UI.Social.ConnCase

   alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

 # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context
    test "As a user, when someone replies to my activity, I want to see it in notifications, include the author' name of the reply" do
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Follows.follow(alice, bob)

      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")

       # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public") #|> IO.inspect

      feed = Bonfire.Social.FeedActivities.feed(:notifications, alice)
      fp = feed.edges
      # |> IO.inspect()
      |> List.first()
      #|> IO.inspect

      assigns = [activity: fp.activity, showing_within: :notifications]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      # |> IO.inspect()
      |> Floki.find("[data-id=subject_name]")
      |> Floki.text() =~ bob.profile.name
    end


    test "As a user, when someone replies to my activity, I want to see it in notifications, include the replied message" do
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Follows.follow(alice, bob)

      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")

       # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public") #|> IO.inspect

      feed = Bonfire.Social.FeedActivities.feed(:notifications, alice)
      fp = feed.edges
      # |> IO.inspect()
      |> List.first()

      assigns = [activity: fp.activity, showing_within: :notifications]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      # |> IO.inspect()
      |> Floki.find("div.reply_message")
      |> Floki.text() =~ "reply to first post"
    end

    test "As a user, when someone replies to my activity, I want to see it in notifications, included the author's name of the original activity" do
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Follows.follow(alice, bob)

      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")

       # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public") #|> IO.inspect

      feed = Bonfire.Social.FeedActivities.feed(:notifications, alice)
      fp = feed.edges
      # |> IO.inspect()
      |> List.first()

      assigns = [activity: fp.activity, showing_within: :notifications]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      # |> IO.inspect()
      |> Floki.find("div.main_reply_to a")
      |> Floki.text() =~ alice.profile.name
    end


    test "As a user, when someone replies to my activity, I want to see it in notifications, included the content of the original activity" do
      account = fake_account!()
      alice = fake_user!(account)

      account2 = fake_account!()
      bob = fake_user!(account2)

      # Follows.follow(alice, bob)

      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post</p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")

       # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "reply to first post"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public") #|> IO.inspect

      feed = Bonfire.Social.FeedActivities.feed(:notifications, alice)
      fp = feed.edges
      # |> IO.inspect()
      |> List.first()

      assigns = [activity: fp.activity, showing_within: :notifications]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      # |> IO.inspect()
      |> Floki.find("div.reply_to")
      |> Floki.text() =~ "first post"
    end


end
