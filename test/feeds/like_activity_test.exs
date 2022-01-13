defmodule Bonfire.UI.Social.Feeds.LikeActivityTest do

  use Bonfire.UI.Social.ConnCase

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

  test "As a user I want to see the activity total likes" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)
    # Create bob user
    account2 = fake_account!()
    bob = fake_user!(account2)
    # bob follows alice
    Follows.follow(bob, alice)
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.text =~ "Like (1)"
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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, like} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.last() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
      |> Floki.parse_fragment
      |> elem(1)
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
      attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
      assert {:ok, post} = Posts.publish(alice, attrs, "public")
      assert {:ok, like} = Likes.like(alice, post)
      assert {:ok, like} = Likes.like(bob, post)

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      fp = feed.edges |> List.first() #|> IO.inspect
      assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

      assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.text =~ "Liked (2)"

  end

  test "As a user, when I like a post, I want to see the activity liked subject" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, like} = Likes.like(bob, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.find("[data-id=subject_name]")
    |> Floki.text =~ alice.profile.name
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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, like} = Likes.like(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, like} = Likes.like(alice, post)
    assert {:ok, like} = Likes.like(bob, post)
    assert unlike = Likes.unlike(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, like} = Likes.like(alice, post)
    assert {:ok, like} = Likes.like(bob, post)
    assert unlike = Likes.unlike(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.text =~ "Like"
  end

end
