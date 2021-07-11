defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do

  use Bonfire.UI.Social.ConnCase
  # alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}


  describe "Feed: Activity actions" do

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

    test "As a user, when I click on reply I am redirected to the activity discussion page" do
    end

    test "As a user, when I like an activity the counter should increment" do
    end

    test "As a user, when I like an activity, the label should change from like to liked" do
    end

    test "As a user when I unlike an activity, the counter should decrement" do
    end

    test "As a user, when I unlike an activity, the label should change from liked to like" do
    end

    test "As a user, when I boost an activity, the counter should increment" do
    end

    test "As a user, when I boost an activity, the label should change from boost to boosted" do
    end
 
    test "As a user, when I unboost an activity, the counter should decrement" do
    end

    test "As a user, when I unboost an activity, the label should change from boosted to boost" do
    end


    # As a Guest
    ## If the user is not logged, we should show a modal when the user clicks on boosts and likes because they may be logged with another server.
  end

  describe "Feed: Check if the activity is rendered as expected" do

    test "As a user, when I create a new post, I want to see my avatar image in the activity subject" do

    end

    test "As a user, when I create a new post, I want to see my name in the activity subject" do

    end

    test "As a user, when I create a new post, I want to see my username next to my name in the activity subject" do

    end

    test "As a user, when I create a new post, I want to see the content as the activity object" do

    end

    test "As a user, when I create a new post, I want to see the reply, boost and like buttons as the activity actions" do

    end

    test "As a user, when I create a new post, I want to see when the post was created" do

    end

    test "As a user I want to see the activity boundary" do

    end

    # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context 
    test "As a user, when someone replies to an activity, I want to see the author' name of the reply" do
    
    end

    test "As a user, when someone replies to an activity, I want to see the reply message" do
    
    end


    test "As a user, when someone replies to an activity, I want to see the subject of the original activity" do
    
    end

    test "As a user, when someone replies to an activity, I want to see the object of the original activity" do
    
    end


    test "As a user I want to click over a link that is part of an activity body and navigate to that link" do

    end

  end

  describe "Feed: Boosted activities" do
    # Boosted activities

    test "As a user, when I boost a post, I want to see the author of the boost the post" do
    
    end

    test "As a user, when I boost a post, I want to see the activity boosted subject" do

    end

    test "As a user, when I boosts a post, I want to see the activity boosted object" do
    
    end

    test "As a user, when I boosts a post, I want to see the activity boosted action" do
    
    end

    test "As a user, when a user I do not follow boosts a post, I want to see the author of the boost the post" do
    
    end

    test "As a user, when a user I do not follow boosts a post, I want to see the activity boosted subject" do

    end

    test "As a user, when a user I do not follow boosts a post, I want to see the activity boosted object" do
    
    end

    test "As a user, when a user I do not follow boosts a post, I want to see the activity boosted action" do
    
    end

    test "As a user, when a user I follow boosts a post, I want to see the author of the boost the post" do
    
    end

    test "As a user, when a user I follow boosts a post, I want to see the activity boosted subject" do

    end

    test "As a user, when a user I follow boosts a post, I want to see the activity boosted object" do
    
    end

    test "As a user, when a user I follow boosts a post, I want to see the activity boosted action" do
    
    end

  end

  describe "Feed: Liked activities" do
    test "As a user, when I like a post, I want to navigate to my profile, and see the author of the like under liked tab" do
    
    end

    test "As a user, when I like a post, I want to navigate to my profile, and see the activity liked subject under liked tab" do

    end

    test "As a user, when I likes a post, I want to navigate to my profile, and see the activity liked object under liked tab" do
    
    end

    test "As a user, when I likes a post, I want to navigate to my profile, and see the activity liked actions under liked tab" do
    
    end

    test "As a user, when a user I do not follow likes a post, I want to navigate to the user profile, and see the author of the like under liked tab" do
    
    end

    test "As a user, when a user I do not follow likes a post, I want to navigate to the user profile, and see the activity liked subject under liked tab" do

    end

    test "As a user, when a user I do not follow likes a post, I want to navigate to the user profile, and see the activity liked object under liked tab" do
    
    end

    test "As a user, when a user I do not follow likes a post, I want to navigate to the user profile, and see the activity liked actions under liked tab" do
    
    end

    test "As a user, when a user I follow likes a post, I want to navigate to the user profile, and see the author of the like under liked tab" do
    
    end

    test "As a user, when a user I follow likes a post, I want to navigate to the user profile, and see the activity liked subject" do

    end

    test "As a user, when a user I follow likes a post, I want to navigate to the user profile, and see the activity liked object" do
    
    end

    test "As a user, when a user I follow likes a post, I want to navigate to the user profile, and see the activity liked actions" do
    
    end
  end


end
