defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do

  use Bonfire.UI.Social.ConnCase
  # alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}


  describe "Feed UX:" do

    @tag :todo
    test "As a user I want to see the activity boundary" do

    end

    test "As a user I want to see the activity total replies" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)

      # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{activity: fp.activity})

      assert doc
        |> Floki.text =~ "Reply (1)"
    end

    test "As a user I want to see the activity total boosts" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{activity: fp.activity})

      assert doc
        |> Floki.text =~ "Boosted (1)"
    end

    test "As a user I want to see the activity total likes" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{activity: fp.activity})

      assert doc
        |> Floki.text =~ "Like (1)"
    end

    test "As a user I want to see if I already boosted an activity" do

    end

    test "As a user I want to see if I already liked an activity" do

    end

    test "As a user I want to see the context a message is replying to" do

    end

    test "As a user I want to click over a link that is part of an activity body and navigate to that link" do

    end

  end


end
