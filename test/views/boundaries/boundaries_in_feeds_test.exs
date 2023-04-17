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
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}", html_body)
    # Then I should boost the post
    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"
           )

    # Then I should comment on the post
    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )

    # Then I should like the post
    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )
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
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # When I login as alice
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    # Then I should not see the post in my feed
    refute has_element?(view, "#activity-#{feed_id}-#{id(post)}")
  end

  test "post with custom boundaries should appear in feed for users who can see it if they follow me" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)

    {:ok, _} = Follows.follow(alice, me)

    # create a circle with alice and bob
    {:ok, circle} = Circles.create(me, %{named: %{name: "family"}})
    {:ok, _} = Circles.add_to_circles(alice, circle)
    {:ok, _} = Circles.add_to_circles(bob, circle)

    # create a post with custom boundary and add family to to_circle
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: attrs,
        boundary: "custom",
        to_circles: %{circle.id => "interact"}
      )

    # login as myself and verify that I can see the post
    conn = conn(user: me, account: account)
    {:ok, view, _html} = live(conn, "/feed")
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, me)
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed")
    # element(view, "[role=feed]") |> render |> debug
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, alice)
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # login as bob and verify that the post is not in my feed
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed")
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, bob)
    refute has_element?(view, "#activity-#{feed_id}-#{id(post)}")
    # but it is in the local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # login as carl and verify that he cannot see the post
    conn = conn(user: carl, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, carl)
    refute has_element?(view, "#activity-#{feed_id}-#{id(post)}")
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

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: attrs,
        boundary: "custom",
        to_circles: %{alice.id => "read", bob.id => "interact"}
      )

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # ...but cannot like
    refute has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    # login as bob and verify that he can like the post
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )
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

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: attrs,
        # note: need to use custom here, because public or local would still grant users the ability to reply
        boundary: "custom",
        to_circles: %{alice.id => "interact", bob.id => "participate"}
      )

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # ...can like and boost but cannot reply
    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"
           )

    refute has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )

    # login as bob and verify that he can like, boost and reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )
  end

  test "adding a user with a 'administer' role and verify that the user can delete the post" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # create a post with local boundary and add Alice as administer
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: attrs,
        boundary: "local",
        to_circles: %{alice.id => "administer"}
      )

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # ...can like, boost and reply
    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )

    # ...can delete the post
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)} [role=delete]")

    # login as bob and verify that he can like, boost and reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]"
           )

    assert has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )

    # but cannot delete the post
    refute has_element?(view, "#activity-#{feed_id}-#{id(post)} [role=delete]")
  end

  test "adding a user with a 'none' role and verify that the user cannot see or interact with the post in any way." do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # bob = fake_user!(account)

    # create a post with local boundary and add Alice as administer
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}

    {:ok, post} =
      Posts.publish(
        current_user: me,
        post_attrs: attrs,
        boundary: "custom",
        to_circles: %{alice.id => "none"}
      )

    # login as alice and verify that she cannot see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    refute has_element?(view, "#activity-#{feed_id}-#{id(post)}")

    # ...cannot like, boost and reply
    refute has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]"
           )

    refute has_element?(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]")

    refute has_element?(
             view,
             "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]"
           )

    # NOTE: 'none' doesn't block alice, it only doesn't assign anything extra, so 'custom' boundary means she (and bob) can't read, but 'local' boundary means they both can

    # login as bob and verify that he can see, like, boost and reply
    # conn = conn(user: bob, account: account)
    # {:ok, view, _html} = live(conn, "/feed/local")
    # activity = element(view, "#activity-#{feed_id}-#{id(post)}")
    # assert has_element?(activity)

    # assert has_element?(
    #          element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=like_enabled]")
    #        )

    # assert has_element?(
    #          element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=boost_enabled]")
    #        )

    # assert has_element?(
    #          element(view, "#activity-#{feed_id}-#{id(post)} button[data-role=reply_enabled]")
    #        )
  end
end
