defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do

  use Bonfire.UI.Social.ConnCase

  # alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

  describe "Feed: Activity actions" do

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
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)

      # Reply to the original post
      attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
      assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)
      assert {:ok, post_reply} = Posts.publish(carl, attrs_reply)
      assert {:ok, post_reply} = Posts.publish(demetrius, attrs_reply)
      assert {:ok, post_reply} = Posts.publish(eve, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.last() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Reply (4)"
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
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(alice, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boost (1)"
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
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Like (1)"
    end

    test "As a user I want to see if I already boosted an activity" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boosted (1)"
    end

    test "As a user I want to see if I already liked an activity" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, like} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.last() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Liked"
    end

    test "As a user, when I like an activity the counter should increment" do
        # Create alice user
        account = fake_account!()
        alice = fake_user!(account)
        # Create bob user
        account2 = fake_account!()
        bob = fake_user!(account2)
        # bob follows alice
        Follows.follow(bob, alice)
        # Alice posts a message
        attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
        assert {:ok, post} = Posts.publish(alice, attrs)
        assert {:ok, like} = Likes.like(alice, post)
        assert {:ok, like} = Likes.like(bob, post)

        feed = Bonfire.Social.FeedActivities.my_feed(bob)
        fp = feed.entries |> List.first() #|> IO.inspect
        assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

        assert doc
        |> Floki.text =~ "Liked (2)"

    end

    test "As a user, when I like an activity, the label should change from like to liked" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      # Alice posts a message
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, like} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.text =~ "Liked"
    end

    test "As a user when I unlike an activity, the counter should decrement" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      # Alice posts a message
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, like} = Likes.like(alice, post)
      assert {:ok, like} = Likes.like(bob, post)
      assert unlike = Likes.unlike(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.text =~ "Like (1)"
    end

    test "As a user, when I unlike an activity, the label should change from liked to like" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      # Alice posts a message
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, like} = Likes.like(alice, post)
      assert {:ok, like} = Likes.like(bob, post)
      assert unlike = Likes.unlike(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.text =~ "Like"
    end

    test "As a user, when I boost an activity, the counter should increment" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(alice, post)

      assert {:ok, boost} = Boosts.boost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boosted (2)"
    end

    test "As a user, when I boost an activity, the label should change from boost to boosted" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(alice, post)

      assert {:ok, boost} = Boosts.boost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boosted"
    end

    test "As a user, when I unboost an activity, the counter should decrement" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(alice, post)

      assert {:ok, boost} = Boosts.boost(bob, post)
      assert unboosted = Boosts.unboost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boost (1)"
    end

    test "As a user, when I unboost an activity, the label should change from boosted to boost" do
      # Create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)
      assert unboosted = Boosts.unboost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boost"
    end


    test "As a user, I want to see the correct amount of times a post were boosted" do
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
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

      assert {:ok, post} = Posts.publish(alice, attrs)

      assert {:ok, boost} = Boosts.boost(alice, post)
      assert {:ok, boost} = Boosts.boost(bob, post)
      assert {:ok, boost} = Boosts.boost(carl, post)
      assert {:ok, boost} = Boosts.boost(demetrius, post)
      assert {:ok, boost} = Boosts.boost(eve, post)
      assert unboosted = Boosts.unboost(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
        |> Floki.text =~ "Boost (4)"
    end


    # As a Guest
    ## If the user is not logged, we should show a modal when the user clicks on boosts and likes because they may be logged with another server.
  end

  describe "Feed: Check if the activity is rendered as expected" do

    test "As a user, when I create a new post, I want to see my avatar image in the activity subject" do
       # Create alice user
       account = fake_account!()
       alice = fake_user!(account)
       attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
       assert {:ok, post} = Posts.publish(alice, attrs)
       feed = Bonfire.Social.FeedActivities.my_feed(alice)
       fp = feed.entries |> List.first() #|> IO.inspect
       assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

       assert doc
       |> Floki.find("img.subject_avatar")
      #  |> Floki.attribute("alt") == [alice.profile.name <> " profile image"]
    end

    test "As a user, when I create a new post, I want to see my name in the activity subject" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_name")
      |> Floki.text() =~ alice.profile.name
    end

    test "As a user, when I create a new post, I want to see my username next to my name in the activity subject" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("span.subject_username")
      |> Floki.text() =~ alice.character.username
    end

    test "As a user, when I create a new post, I want to see the content as the activity object" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("div.object_body")
      |> Floki.text() =~ "first post"
    end


    test "As a user, when I create a new post, I want to see when the post was created" do
      account = fake_account!()
      alice = fake_user!(account)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_timestamp")
      |> Floki.text() =~ "3 minutes ago"
    end

    # When an activity is a reply to another one, in the feed I want to see both activities: the original activity and the reply with enough information to understand the context
    test "As a user, when someone replies to an activity, I want to see the author' name of the reply" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)

       # Reply to the original post
       attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
       assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_name")
      |> Floki.text() =~ bob.profile.name
    end

    test "As a user, when someone replies to an activity, I want to see the reply message" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)

       # Reply to the original post
       attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
       assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)
      assert doc
      |> Floki.find("div.object_body")
      |> List.last
      |> Floki.text =~ "reply to first post"
    end


    test "As a user, when someone replies to an activity, I want to see the subject of the original activity" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)

       # Reply to the original post
       attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
       assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)
      assert doc
      |> Floki.find("a.subject_replied")
      |> Floki.text() =~ alice.profile.name
    end

    test "As a user, when someone replies to an activity, I want to see the object of the original activity" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)

       # Reply to the original post
       attrs_reply = %{post_content: %{summary: "summary", name: "name 2", html_body: "<p>reply to first post</p>"}, reply_to_id: post.id}
       assert {:ok, post_reply} = Posts.publish(bob, attrs_reply)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)
      assert doc
      |> Floki.find("div.object_body")
      |> List.first
      |> Floki.text =~ "first post"
    end

  end

  describe "Feed: Boosted activities" do
    # Boosted activities

    test "As a user, when I boost a post, I want to see the author of the boost the post" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_minimal")
      |> List.first
      |> Floki.text =~ bob.profile.name

    end

    test "As a user, when I boost a post, I want to see the activity boosted subject" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_name")
      |> Floki.text =~ alice.profile.name
    end

    test "As a user, when I boosts a post, I want to see the activity boosted object" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)
      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("div.object_body")
      |> Floki.text =~ "first post"
    end

    test "As a user, when a user I do not follow boosts a post, I want to see the boost activity author in the instance timeline" do
      account = fake_account!()
      alice = fake_user!(account)
      account2 = fake_account!()
      bob = fake_user!(account2)
      account3 = fake_account!()
      carl = fake_user!(account3)

      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}
      assert {:ok, post} = Posts.publish(alice, attrs)
      assert {:ok, boost} = Boosts.boost(bob, post)
      feed_id = Bonfire.Social.Feeds.instance_feed_id()
      feed = Bonfire.Social.FeedActivities.feed(feed_id, carl)
      fp = feed.entries |> List.first() #|> IO.inspect
      assigns = %{activity: fp.activity}
      assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.find("a.subject_minimal")
      |> List.first
      |> Floki.text =~ bob.profile.name
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
