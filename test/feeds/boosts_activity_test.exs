defmodule Bonfire.UI.Social.Feeds.BoostsActivityTest do

  use Bonfire.UI.Social.ConnCase

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

  test "As a user I want to see the activity total boosts" do
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
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert {:ok, boost} = Boosts.boost(carl, post)
    assert {:ok, boost} = Boosts.boost(demetrius, post)
    assert {:ok, boost} = Boosts.boost(eve, post)
    assert unboosted = Boosts.unboost(eve, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.find("[data-id=boost_action]")
    |> Floki.text =~ "Boost (3)"
  end

  test "As a user I want to see if I already boosted an activity" do
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
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert {:ok, boost} = Boosts.boost(carl, post)
    assert {:ok, boost} = Boosts.boost(demetrius, post)
    assert {:ok, boost} = Boosts.boost(eve, post)
    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.find("[data-id=boost_action]")
    |> Floki.text =~ "Boosted (4)"
  end


  test "As a user, when I boost a post, I want to see the activity boosted subject" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
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

  test "As a user, when I boosts a post, I want to see the activity boosted object" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.find("div.object_body")
    |> Floki.text =~ "first post"
  end


  test "As a user, when I boost a post, I want to see the author of the boost" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    # bob follows alice
    Follows.follow(alice, bob)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
    |> Floki.parse_fragment
    |> elem(1)
    |> Floki.find("a.subject_minimal")
    |> List.first
    |> Floki.text =~ bob.profile.name

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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Boosts.boost(alice, post)

    assert {:ok, boost} = Boosts.boost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boosted (2)"
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
    attrs = %{to_circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(alice, attrs, "public")
    assert {:ok, boost} = Boosts.boost(alice, post)

    assert {:ok, boost} = Boosts.boost(bob, post)
    assert unboosted = Boosts.unboost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boost (1)"
  end

  test "As a user, when I unboost an activity, the label should change to boost" do
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
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert unboosted = Boosts.unboost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assigns = [activity: fp.activity]
    assert doc = render_surface(Bonfire.UI.Social.ActivityLive, assigns)

    assert doc
      |> Floki.parse_fragment
      |> elem(1)
      |> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boost"
  end



end
