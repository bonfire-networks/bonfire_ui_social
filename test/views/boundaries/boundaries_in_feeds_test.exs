defmodule Bonfire.Social.Activities.BoundariesInFeedsTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Follows
  import Bonfire.Common.Enums
  alias Bonfire.Boundaries.Circles

  test "creating a post with boundaries public and verify that all users can see and interact with it" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    account = fake_account!()
    me = fake_user!(account)
    bob = fake_user!(account)
    # When I login
    conn = conn(user: me, account: account)
    html_body = "epic html message"
    # And bob creates a post with a 'public' boundary
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

    {:ok, view, _html} = live(conn, "/feed/local")

    # Then I should see the post in my feed
    activity = element(view, "#activity-#{feed_id}-#{id(post)}", html_body)
    assert has_element?(activity)
    # Then I should boost the post
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    # Then I should comment on the post
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))
    # Then I should like the post
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
  end


  test "creating a post with a 'mention' boundary and verify that only mentioned users can see and interact with it." do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    # When I login
    conn = conn(user: me, account: account)
    attrs = %{post_content: %{html_body: "@#{me.character.username} hello!</p>"}}
    assert {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "mentions")

    {:ok, view, _html} = live(conn, "/feed/local")

    # Then I should see the post in my feed
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    assert has_element?(activity)

    # When I login as alice
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    # Then I should not see the post in my feed
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    refute has_element?(activity)
  end

  test "Test creating a post with a 'custom' boundary and verify that only users that belong to the circle selected can read the post." do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    # create a circle with alice and bob
    {:ok, circle} = Circles.create(me, %{named: %{name: "family"}})
    {:ok, circle} = Circles.add_to_circles(alice, circle)
    {:ok, circle} = Circles.add_to_circles(bob, circle)

    # create a post with custom boundary and add family to to_circle
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "custom", to_circles: %{circle.id => "read"})

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/post/#{post.id}")
    activity = element(view, "#ot-#{id(post)}")
    assert has_element?(activity)

    # login as bob and verify that he can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/post/#{post.id}")
    activity = element(view, "#ot-#{id(post)}")
    assert has_element?(activity)

    # login as carl and verify that he cannot see the post
    conn = conn(user: carl, account: account)
    {:ok, view, _html} = live(conn, "/post/#{post.id}")
    activity = element(view, "#ot-#{id(post)}")
    refute has_element?(activity)

  end

  test "Test adding a user with a 'read' role and verify that the user can see the post but not interact with it." do
    # create a post with public boundary and give alice only see permissions
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # create a post with local boundary and add Alice as Reader
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "local", to_circles: %{alice.id => "read"})

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    assert has_element?(activity)

    # ...but cannot like
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))

    # login as bob and verify that he can like the post
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))

  end

  test "adding a user with an 'interact' role and verify that the user can like and boost the post." do
    # create a post with public boundary and give alice only see permissions
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # create a post with local boundary and add Alice as Reader
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "local", to_circles: %{alice.id => "interact"})

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    assert has_element?(activity)

    # ...can like and boost but cannot reply
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))

    # login as bob and verify that he can like, boost and reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))

  end

  test "adding a user with a 'participate' role and verify that the user can engage in the post's activities and discussions." do
     # create a bunch of users
     account = fake_account!()
     me = fake_user!(account)
     alice = fake_user!(account)
     bob = fake_user!(account)

     # create a post with local boundary and add Alice as participate
     html_body = "epic html message"
     attrs = %{post_content: %{html_body: html_body}}
     {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "custom", to_circles: %{alice.id => "participate"})

     # login as alice and verify that she can see the post
     conn = conn(user: alice, account: account)
     {:ok, view, _html} = live(conn, "/post/#{post.id}")
     activity = element(view, "#ot-#{id(post)}")
     assert has_element?(activity)

     # ...can like and boost but cannot reply
     assert has_element?(element(view, "#ot-#{id(post)} button[data-role=like_enabled]"))
     assert has_element?(element(view, "#ot-#{id(post)} button[data-role=boost_enabled]"))
     assert has_element?(element(view, "#ot-#{id(post)} button[data-role=reply_enabled]"))

     # login as bob and verify that he cannot see, like, boost and reply
     conn = conn(user: bob, account: account)
     {:ok, view, _html} = live(conn, "/post/#{post.id}")
     refute has_element?(element(view, "#ot-#{id(post)} button[data-role=like_enabled]"))
     refute has_element?(element(view, "#ot-#{id(post)} button[data-role=boost_enabled]"))
     refute has_element?(element(view, "#ot-#{id(post)} button[data-role=reply_enabled]"))
  end

  test "adding a user with a 'caretaker' role and verify that the user can delete the post" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # create a post with local boundary and add Alice as caretaker
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "local", to_circles: %{alice.id => "caretaker"})

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    assert has_element?(activity)

    # ...can like, boost and reply
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))

    # ...can delete the post
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} [data-role=delete-object-btn]"))

    # login as bob and verify that he can like, boost and reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))

    # but cannot delete the post
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} [data-role=delete-object-btn]"))
  end

  test "adding a user with a 'none' role and verify that the user cannot see or interact with the post in any way." do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # create a post with local boundary and add Alice as caretaker
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "local", to_circles: %{alice.id => "none"})

    # login as alice and verify that she cannot see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    refute has_element?(activity)

    # ...cannot like, boost and reply
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    refute has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))


    # login as bob and verify that he can see, like, boost and reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    assert has_element?(activity)
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"))
    assert has_element?(element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"))

  end


  test "creating a post with a custom boundary, and verify that only users within the boundary can access the post according to their assigned roles." do

  end















end
