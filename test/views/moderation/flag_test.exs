defmodule Bonfire.Social.Moderation.FlagTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Files.Test
  import Bonfire.Common.Enums

  test "Flagging a post works" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    # Then I should see the post in my feed
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}", content)
    # then I flag the post
    view
    |> element(
      "#activity-#{feed_id}-#{id(post)} li[data-role=flag_object] div[data-role=open_modal]"
    )
    |> render_click()

    view |> element("button[data-role=submit_flag]") |> render_click()

    assert render(view) =~ "flagged!"
  end

  # WIP: this test is failing in the browser, but passing in the terminal
  test "My flags should not appear on local feed" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, _flag} = Bonfire.Social.Flags.flag(me, post.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    # I should not see my flag on the feed
    # open_browser(view)
    refute has_element?(view, "div[data-role=flagged_by]")
  end

  # WIP: this test is failing in the browser, but passing in the terminal
  test "Flags from other users should not appear on local feed" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, _flag} = Bonfire.Social.Flags.flag(me, post.id)
    # login as bob
    conn = conn(user: bob, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    # I should not see my flag on the feed
    # open_browser(view)
    refute has_element?(view, "div[data-role=flagged_by]")
  end

  test "If I already flagged an activity, I want to be told rather than be able to attempt flagging twice" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, _flag} = Bonfire.Social.Flags.flag(me, post.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    # Then I should see the post in my feed
    # open_browser(view)
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}", content)

    # does the actions menu show that it's already flagged? 
    # assert render(view) =~ "Already flagged"

    debug("now open the modal")

    view
    |> element(
      "#activity-#{feed_id}-#{id(post)} li[data-role=flag_object] div[data-role=open_modal]"
    )
    |> render_click()

    # does the modal say that it's already flagged?
    assert render(view) =~ "Already flagged"
  end

  test "Flagging a user works" do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/feed/local")
    # Then I should see the post in my feed 
    assert has_element?(view, "#activity-#{feed_id}-#{id(post)}", content)
    # then I flag the post
    view
    |> element(
      "#activity-#{feed_id}-#{id(post)} li[data-role=flag_author] div[data-role=open_modal]"
    )
    |> render_click()

    view |> element("button[data-role=submit_flag]") |> render_click()

    assert_flash(view, :info, "flagged!")

    {:ok, view, _html} = live(conn, "/settings/flags")
    open_browser(view)
    list = element(view, "#flags_list")
    assert render(list) =~ alice.profile.name
    refute render(list) =~ content, "oops, did we flag the post rather than the user?"
  end

  test "When I flag an activity, I want to see the flag in my flags feed in settings" do
    # feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, flag} = Bonfire.Social.Flags.flag(me, post.id)
    # login as me 
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/settings/flags")
    # Then I should see the post in my feed
    assert has_element?(view, "#activity-flags-#{id(flag)}", content)
  end

  test "Unflag a post works" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, flag} = Bonfire.Social.Flags.flag(me, post.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/settings/flags")
    # Then I should see the post in my feed
    # open_browser(view) 
    assert has_element?(view, "#activity-flags-#{id(flag)}", content)
    # then I unflag the post
    view |> element("button[data-role=unflag]") |> render_click()
    assert render(view) =~ "Unflagged!"
    # WIP instantly update the flag feed
    refute has_element?(view, "#activity-flags-#{id(flag)}", content)
  end

  test "Unflag a user works" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    {:ok, flag} = Bonfire.Social.Flags.flag(me, alice.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to local feed
    {:ok, view, _html} = live(conn, "/settings/flags")
    # Then I should see the user in the flagged list
    # open_browser(view)
    activity = element(view, "#activity-flags-#{id(flag)}")
    assert has_element?(activity)
    assert render(activity) =~ alice.profile.name
    # then I unflag the post
    view |> element("button[data-role=unflag]") |> render_click()
    assert render(view) =~ "Unflagged!"
    # WIP instantly update the flag feed
    activity = element(view, "#activity-flags-#{id(flag)}")
    refute render(activity) =~ alice.profile.name
  end

  test "As an admin, When a user flags an activity I want to see the activity in flags feed in admin settings" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    # make myself an admin
    Bonfire.Me.Users.make_admin(me)
    # alice creates a post
    content = "here is an epic html post"
    attrs = %{post_content: %{html_body: content}}
    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "local")
    {:ok, flag} = Bonfire.Social.Flags.flag(bob, post.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to admin settings flags feed
    {:ok, view, _html} = live(conn, "/settings/instance/flags")
    # Then I should see the post in my feed
    assert has_element?(view, "#activity-flags-#{id(flag)}", content)
  end

  test "As an admin, When a user flags another user I want to see the user flagged in flags feed in admin settings" do
    # create a bunch of users
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)
    # make myself an admin
    Bonfire.Me.Users.make_admin(me)
    # alice creates a post
    {:ok, flag} = Bonfire.Social.Flags.flag(bob, alice.id)
    # login as me
    conn = conn(user: me, account: account)
    # navigate to admin settings flags feed
    {:ok, view, _html} = live(conn, "/settings/instance/flags")
    # Then I should see the post in my feed
    assert has_element?(view, "#activity-flags-#{id(flag)}")
  end

  # can add once we implement custom roles
  # test "If I have the right instance permission, as a user I want to see and act upon the flags feed in admin settings" do

  # end
end
