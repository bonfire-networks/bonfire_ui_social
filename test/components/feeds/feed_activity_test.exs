defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Posts

  alias Bonfire.Common.Repo

  test "As a user I want to see the activity total replies" do
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
      carl = fake_user!(account2)
      demetrius = fake_user!(account)
      eve = fake_user!(account)
      # bob follows alice
      Follows.follow(bob, alice)

      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Reply to the original post
      attrs_reply = %{
        post_content: %{summary: "summary", name: "name 2", html_body: "reply to post"},
        reply_to_id: post.id
      }

      assert {:ok, post_reply} =
               Posts.publish(current_user: bob, post_attrs: attrs_reply, boundary: "public")

      assert {:ok, post_reply} =
               Posts.publish(current_user: carl, post_attrs: attrs_reply, boundary: "public")

      assert {:ok, post_reply} =
               Posts.publish(current_user: demetrius, post_attrs: attrs_reply, boundary: "public")

      assert {:ok, post_reply} =
               Posts.publish(current_user: eve, post_attrs: attrs_reply, boundary: "public")

      feed = Bonfire.Social.FeedActivities.my_feed(bob)
      # |> IO.inspect
      fp = feed.edges |> List.last()

      assert doc =
               render_stateful(Bonfire.UI.Social.ActivityLive, %{
                 id: "activity",
                 activity: fp.activity
               })

      assert doc
             |> Floki.parse_fragment()
             |> elem(1)
             |> Floki.text() =~ "Reply (4)"
    end
  end

  test "As a user, when I create a new post, I want to see my avatar image in the activity subject" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
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
           |> elem(1)
           |> Floki.find("img.avatar")

    #  |> Floki.attribute("alt") == [alice.profile.name <> " profile image"]
  end

  test "As a user, when I create a new post, I want to see my name in the activity subject" do
    account = fake_account!()
    alice = fake_user!(account)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
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

  test "As a user, when I create a new post, I want to see my username next to my name in the activity subject" do
    account = fake_account!()
    alice = fake_user!(account)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
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
           ~> Floki.find("span.subject_username")
           |> Floki.text() =~ alice.character.username
  end

  test "As a user, when I create a new post, I want to see the content in the activity object" do
    account = fake_account!()
    alice = fake_user!(account)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    feed = Bonfire.Social.FeedActivities.my_feed(alice)

    fp =
      feed.edges
      |> List.first()
      |> info()

    assert doc =
             render_stateful(Bonfire.UI.Social.ActivityLive, %{
               id: "activity",
               activity: fp.activity
             })

    assert doc
           # |> Floki.parse_fragment
           # ~> Floki.find("div.object_body")
           |> Floki.text() =~ "first post"
  end

  test "As a user, when I create a new post, I want to see when the post was created" do
    account = fake_account!()
    alice = fake_user!(account)

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
    }

    assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
    feed = Bonfire.Social.FeedActivities.my_feed(alice)
    # |> IO.inspect
    fp = feed.edges |> List.first()

    assert doc =
             render_stateful(Bonfire.UI.Social.ActivityLive, %{
               id: "activity",
               activity: fp.activity
             })

    time =
      doc
      |> Floki.parse_fragment()
      ~> Floki.find("a.subject_timestamp")
      |> Floki.text()
      |> info()

    assert time =~ "now" || time =~ "second ago" || time =~ "seconds ago"
  end
end
