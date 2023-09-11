defmodule Bonfire.Social.Activities.NegativeBoundariesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Follows
  import Bonfire.Common.Enums
  alias Bonfire.Boundaries.Circles

  test "Test adding a user with a 'cannot read' role and verify that the user cannot see the post in the local timeline nor interact with it but another local user can." do
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
        boundary: "public",
        to_circles: %{alice.id => "cannot_read"}
      )

    # login as alice and verify that she cannot see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    refute has_element?(view, "article")

    # ...and cannot like and boost
    refute has_element?(
             view,
             "article button[data-role=like_enabled]"
           )

    # ...and cannot like
    refute has_element?(
             view,
             "article button[data-role=boost_enabled]"
           )

    # login as bob and verify that he can like the post
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "article button[data-role=like_enabled]"
           )
  end

  test "Test adding a user with a 'cannot interact' role and verify that the user can see the post but not interact with it but another local user can." do
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
        boundary: "public",
        to_circles: %{alice.id => "cannot_interact"}
      )

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(view, "article")

    # ...but cannot like and boost
    refute has_element?(
             view,
             "article button[data-role=like_enabled]"
           )

    refute has_element?(
             view,
             "article button[data-role=boost_enabled]"
           )

    # login as bob and verify that he can like the post
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "article button[data-role=like_enabled]"
           )
  end

  test "Test adding a user with a 'cannot participate' role and verify that the user can see and interact with the post but not reply to it but another local user can." do
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
        boundary: "public",
        to_circles: %{alice.id => "cannot_participate"}
      )

    # login as alice and verify that she can see the post
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")
    assert has_element?(view, "article")

    # ...can like and bosst
    assert has_element?(
             view,
             "article button[data-role=like_enabled]"
           )

    assert has_element?(
             view,
             "article button[data-role=boost_enabled]"
           )

    # ...but cannot reply
    refute has_element?(
             view,
             "article button[data-role=reply_enabled]"
           )

    # login as bob and verify that he can reply
    conn = conn(user: bob, account: account)
    {:ok, view, _html} = live(conn, "/feed/local")

    assert has_element?(
             view,
             "article button[data-role=reply_enabled]"
           )
  end
end
