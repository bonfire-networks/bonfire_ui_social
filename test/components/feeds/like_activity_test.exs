defmodule Bonfire.UI.Social.Feeds.LikeActivityTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Posts

  test "As a user I want to see the activity total likes" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil,
         current_user: alice,
         current_account: account
       ) do
      # Create bob user
      account2 = fake_account!()
      bob = fake_user!(account2)
      # bob follows alice
      Follows.follow(bob, alice)

      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      assert {:ok, boost} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(alice)
      # |> IO.inspect
      fp = feed.edges |> List.first()

      assert doc =
               render_stateful(Bonfire.UI.Social.ActivityLive, %{
                 id: "activity",
                 activity: fp.activity
               })

      assert doc
             |> Floki.parse_fragment()
             ~> Floki.text() =~ "Like (1)"
    end
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

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, like} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(
               Bonfire.UI.Social.ActivityLive,
               %{id: "activity", activity: fp.activity},
               %{current_user: bob}
             )

    assert doc
           |> Floki.parse_fragment()
           ~> Floki.text() =~ "Liked"
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
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, like} = Likes.like(alice, post)
    assert {:ok, like} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(
               Bonfire.UI.Social.ActivityLive,
               %{id: "activity", activity: fp.activity},
               %{current_user: bob}
             )

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil,
         current_user: bob,
         current_account: account2
       ) do
      assert doc
             |> Floki.parse_fragment()
             ~> Floki.text() =~ "Liked (2)"
    else
      assert doc
             |> Floki.parse_fragment()
             ~> Floki.text() =~ "Liked"
    end
  end

  test "As a user, when I like a post, I want to see the activity liked subject" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, like} = Likes.like(bob, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(Bonfire.UI.Social.ActivityLive, %{
               id: "activity",
               activity: fp.activity
             })

    assert doc
           |> Floki.parse_fragment()
           ~> Floki.find("[data-id=subject_name]")
           |> Floki.text() =~ alice.profile.name
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
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, like} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(
               Bonfire.UI.Social.ActivityLive,
               %{id: "activity", activity: fp.activity},
               %{current_user: bob}
             )

    assert doc
           |> Floki.parse_fragment()
           ~> Floki.text() =~ "Liked"
  end

  test "As a user when I unlike an activity, the counter should decrement" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)

    # Create bob user
    account2 = fake_account!()
    bob = fake_user!(account2)

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil,
         current_user: bob,
         current_account: account2
       ) do
      # bob follows alice
      Follows.follow(bob, alice)
      # Alice posts a message
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      assert {:ok, like} = Likes.like(alice, post)
      assert {:ok, like} = Likes.like(bob, post)
      assert unlike = Likes.unlike(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      # |> IO.inspect
      fp = feed.edges |> List.first()

      assert doc =
               render_stateful(Bonfire.UI.Social.ActivityLive, %{
                 id: "activity",
                 activity: fp.activity
               })

      assert doc
             |> Floki.parse_fragment()
             ~> Floki.text() =~ "Like (1)"
    end
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
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, like} = Likes.like(alice, post)
    assert {:ok, like} = Likes.like(bob, post)
    assert unlike = Likes.unlike(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(Bonfire.UI.Social.ActivityLive, %{
               id: "activity",
               activity: fp.activity
             })

    assert doc
           |> Floki.parse_fragment()
           ~> Floki.text() =~ "Like"
  end
end
