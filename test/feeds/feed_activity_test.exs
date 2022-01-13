defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do

  use Bonfire.UI.Social.ConnCase

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo


    test "As a user I want to see the activity total replies" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      carl = fake_user!(account2)
      demetrius = fake_user!(account)
      eve = fake_user!(account)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

      assert {:ok, post} = Posts.publish(alice, attrs, "public")

      # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "reply to post"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply, "public")
      assert {:ok, post_reply} = Posts.publish(carl, attrs_reply, "public")
      assert {:ok, post_reply} = Posts.publish(demetrius, attrs_reply, "public")
      assert {:ok, post_reply} = Posts.publish(eve, attrs_reply, "public")

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.edges |> List.last() #|> IO.inspect
      assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.parse_fragment
        |> elem(1)
        |> Floki.text =~ "Reply (4)"
    end

    test "As a user, when I create a new post, I want to see my avatar image in the activity subject" do
       # Create alice user
       account = fake_account!()
       alice = fake_user!(account)
       attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
       assert {:ok, post} = Posts.publish(alice, attrs, "public")
       feed = Bonfire.Social.FeedActivities.my_feed(alice)
       fp = feed.edges |> List.first() #|> IO.inspect
       assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

       assert doc
       |> Floki.parse_fragment
       |> elem(1)
       |> Floki.find("img.subject_avatar")
      #  |> Floki.attribute("alt") == [alice.profile.name <> " profile image"]
    end

    test "As a user, when I create a new post, I want to see my name in the activity subject" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.edges |> List.first() #|> IO.inspect
      assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("[data-id=subject_name]")
      |> Floki.text() =~ alice.profile.name
    end

    test "As a user, when I create a new post, I want to see my username next to my name in the activity subject" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.edges |> List.first() #|> IO.inspect
      assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("span.subject_username")
      |> Floki.text() =~ alice.character.username
    end

    test "As a user, when I create a new post, I want to see the content as the activity object" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.edges |> List.first() #|> IO.inspect
      assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("div.object_body")
      |> Floki.text() =~ "first post"
    end


    test "As a user, when I create a new post, I want to see when the post was created" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.edges |> List.first() #|> IO.inspect
      assigns = [activity: fp.activity]
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("a.subject_timestamp")
      |> Floki.text() =~ "3 minutes ago"
    end


end
