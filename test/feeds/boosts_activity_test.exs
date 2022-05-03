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

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: alice, current_account: account) do
    # Create bob user
    account2 = fake_account!()
    bob = fake_user!(account2)
    carl = fake_user!(account2)
    demetrius = fake_user!(account)
    eve = fake_user!(account)
    # bob follows alice
    Follows.follow(bob, alice)
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert {:ok, boost} = Boosts.boost(carl, post)
    assert {:ok, boost} = Boosts.boost(demetrius, post)
    assert {:ok, boost} = Boosts.boost(eve, post)
    assert unboosted = Boosts.unboost(eve, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
    |> Floki.parse_fragment
    ~> Floki.find("[data-id=boost_action]")
    |> Floki.text =~ "Boost (3)"
  end
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
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert {:ok, boost} = Boosts.boost(carl, post)
    assert {:ok, boost} = Boosts.boost(demetrius, post)
    assert {:ok, boost} = Boosts.boost(eve, post)
    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity, __context__: %{current_user: bob}})

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: bob, current_account: account2) do
      assert doc
      |> Floki.parse_fragment
      ~> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boosted (4)"
    else
      assert doc
      |> Floki.parse_fragment
      ~> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boosted"
    end
  end


  test "As a user, when I boost a post, I want to see the activity boosted subject" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
    |> Floki.parse_fragment
    ~> Floki.find("[data-id=subject_name]")
    |> Floki.text =~ alice.profile.name
  end

  test "As a user, when I boosts a post, I want to see the activity boosted object" do
    account = fake_account!()
    alice = fake_user!(account)
    account2 = fake_account!()
    bob = fake_user!(account2)
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
    |> Floki.parse_fragment
    ~> Floki.find("div.object_body")
    |> Floki.text =~ "first post"
  end


  test "As a user, when I boost a post, I want to see the author of the boost" do
    alice = fake_user!("alice")
    bob = fake_user!("bob")
    # bob follows alice
    Follows.follow(alice, bob)

    attrs = %{post_content: %{summary: "summary", name: "test post by alice", html_body: "first post"}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    assert {:ok, boost} = Boosts.boost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
    |> Floki.parse_fragment
    ~> Floki.find("[data-id=subject]")
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

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: bob, current_account: account2) do

    # bob follows alice
    Follows.follow(bob, alice)
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(alice, post)

    assert {:ok, boost} = Boosts.boost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
      |> Floki.parse_fragment
      ~> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boosted (2)"
  end
  end

  test "As a user, when I unboost an activity, the counter should decrement" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)
    # Create bob user
    account2 = fake_account!()
    bob = fake_user!(account2)

    if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: bob, current_account: account2) do

    # bob follows alice
    Follows.follow(bob, alice)
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(alice, post)

    assert {:ok, boost} = Boosts.boost(bob, post)
    assert unboosted = Boosts.unboost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
      |> Floki.parse_fragment
      ~> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boost (1)"
  end
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
    attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "first post"}}

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    assert {:ok, boost} = Boosts.boost(bob, post)
    assert unboosted = Boosts.unboost(bob, post)

    feed = Bonfire.Social.FeedActivities.my_feed(bob)
    fp = feed.edges |> List.first() #|> IO.inspect
    assert doc = render_component(Bonfire.UI.Social.ActivityLive, %{id: "activity", activity: fp.activity})

    assert doc
      |> Floki.parse_fragment
      ~> Floki.find("[data-id=boost_action]")
      |> Floki.text =~ "Boost"
  end



end
