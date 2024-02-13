defmodule Bonfire.UI.Social.BrowsingTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Common.Config
  # alias Bonfire.Social.Fake
  # alias Bonfire.Me.Users
  # alias Bonfire.Social.Boosts
  # alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup_all do
    orig1 = Config.get!(:pagination_hard_max_limit)

    orig2 = Config.get!(:default_pagination_limit)

    Config.put(:pagination_hard_max_limit, 10)

    Config.put(:default_pagination_limit, 10)

    on_exit(fn ->
      Config.put(:pagination_hard_max_limit, orig1)

      Config.put(:default_pagination_limit, orig2)
    end)
  end

  test "Alice pins a post, the post is pinned on her timeline" do
    # Alice pins a post

    # Alice navigates to her profile
    # Alice sees the post pinned
  end

  test "Switch from chronological feed to most replied works" do
    # create 3 posts, with different replies
    # Config.put(:default_pagination_limit, 10)
    # Config.put(:pagination_hard_max_limit, 10)

    account = fake_account!()
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    assert {:ok, _} = Follows.follow(alice, bob)
    assert {:ok, _} = Follows.follow(alice, carl)

    # alice creates a post
    attrs = %{
      post_content: %{html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    attrs_reply = %{
      post_content: %{html_body: "<p>reply to first post</p>"},
      reply_to_id: post.id
    }

    assert {:ok, reply2} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    assert {:ok, reply3} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    assert {:ok, reply4} =
             Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

    assert {:ok, reply5} =
             Posts.publish(current_user: carl, post_attrs: attrs, boundary: "public")

    attrs_reply = %{
      post_content: %{html_body: "<p>reply to first post</p>"},
      reply_to_id: reply5.id
    }

    assert {:ok, reply6} =
             Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")

    assert {:ok, reply7} =
             Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")

    # login as alice
    conn = conn(user: alice, account: account)
    # navigate to the my feed
    next = "/feed"
    {:ok, view, _html} = live(conn, next)

    #  check the first article tag has 0 replies

    # the first comment shown has 0 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] article:first-child div[data-role=reply_action]",
             "0"
           )

    # the second comment shown has 0 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] > div:nth-child(2) div[data-role=reply_action]",
             "0"
           )

    # the third comment shown has 2 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] div:nth-child(3) div[data-role=reply_action]",
             "2"
           )

    # the fourth comment shown has 0 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] div:nth-child(4) div[data-role=reply_action]",
             "0"
           )

    # the fifth comment shown has 0 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] div:nth-child(5) div[data-role=reply_action]",
             "0"
           )

    # the sixth comment shown has 0 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] div:nth-child(6) div[data-role=reply_action]",
             "0"
           )

    # the seventh comment shown has 3 replies
    assert has_element?(
             view,
             "div[data-id=feed_activity_list] div:nth-child(7) div[data-role=reply_action]",
             "3"
           )

    # change the feed controls on "by amount of replies"
    # click on the "by amount of replies"
    assert has_element?(
             view,
             "[data-role=amount_of_replies]",
             "By amount of replies"
           )

    view
    |> element("li[data-role=amount_of_replies]")
    |> render_click()

    live_pubsub_wait(view)
    :timer.sleep(5000)
    # open_browser(view)
  end

  test "Alice boosts Bob post, navigate to local feed with alice, the boosted activity does not show the subject (alice)" do
    # it works on other feeds, but not on local feed
    account = fake_account!()
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

    # carl creates a post
    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    assert {:ok, _} = Follows.follow(alice, bob)

    # login as carl
    conn = conn(user: carl, account: account)
    next = "/feed/local"
    # navigate to the local feed
    {:ok, view, _html} = live(conn, next)
    # open_browser(view)
    # # wait 5 seconds
    # :timer.sleep(5000)
    # open_browser(view)

    # Then I should see the post in my feed
    assert has_element?(view, "a[data-id=subject_name]", alice.profile.name)
  end

  test "Alice navigate to bob profile, try to add bob in a circle, the list of circles is empty even if alice has circles" do
  end

  test "Alice navigate to bob profile, try to add bob in a circle, creates a new circle and add bob, but the circles does not exist later" do
  end

  test "When unfollowing a followed user in their profile, the button breaks and shows a follow button and within an unfollow button" do
  end

  test "I cannot add a circle when customising the boundaries in composer (it is not added to the list)" do
  end

  test "Click to customise the public boundary -> edit the local users circle to read -> click done -> click to customise the local boundary -> the boundary is wrong)" do
    # Even if I've already edited a boundary, if I press on the customise button again, the boundary should reset to the one I've just decided to edit -> the local one in this case
  end

  # UI
  test "In the navigation sidebar, clicking on Favourites does not highlight the link" do
  end

  test "Navigate to a user profile -> click to send a DM -> the composer with the right field to send DM  shows up -> click on compose on the left sidebar -> the composer does not default to the normal composer (with boundaries etc.)" do
  end

  test "editing the circle name does not update instantly" do
  end

  test "unlinking a post from the favourites feed does not remove it instantly" do
  end

  test "even if the likes feed has 0 items, it shows the 'show older activities' button instead of the empty message" do
  end

  test "editing the CW of a post doesn't update it" do
  end

  test "change theme does not instant update the theme" do
  end

  test "feed activities preferences iun user settings behavirous does not switch" do
  end

  test "feed default sort has no active otion" do
  end
end
