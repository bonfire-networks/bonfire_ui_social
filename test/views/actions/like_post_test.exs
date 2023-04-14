defmodule Bonfire.Social.Activities.LikePost.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  import Bonfire.Common.Enums

    test "like a post" do
      poster = fake_user!()
      content = "here is an epic html post"
      attrs = %{post_content: %{html_body: content}}

      assert {:ok, post} =
               Posts.publish(current_user: poster, post_attrs: attrs, boundary: "local")

      some_account = fake_account!()
      someone = fake_user!(some_account)
      conn = conn(user: someone, account: some_account)

      next = "/feed/local"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert view
             |> element("[data-id='like_action']")
             # |> info
             |> render_click()

      # the html returned by render_click isn't updated to show the change (probably because it uses ComponentID and pubsub) even though this works in the browser
      live_pubsub_wait(view)

      assert view
             |> render()
             |> debug()
             ~> Floki.find("[data-id=like_action]")
             |> Floki.text() =~ "Liked"

      assert true == Likes.liked?(someone, post)
    end

    # test "shows the right number of likes" do
    #   poster = fake_user!()
    #   content = "here is an epic html post"
    #   attrs = %{post_content: %{html_body: content}}
    #   assert {:ok, post} = Posts.publish(current_user: poster, post_attrs: attrs, boundary: "local")

    #   assert {:ok, like} = Likes.like(fake_user!(), post)
    #   assert {:ok, like} = Likes.like(fake_user!(), post)

    #   some_account = fake_account!()
    #   someone = fake_user!(some_account)
    #   conn = conn(user: someone, account: some_account)

    #   next = "/feed/local"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect

    #   assert view
    #   |> element("[data-id='like_action']")
    #   |> render()
    #   # |> IO.inspect
    #   |> Floki.text() =~ "Like (2)"

    #   assert view
    #   |> element("[data-id='like_action']")
    #   |> render_click()
    #   |> Floki.text() =~ "Liked (3)"

    #   assert true == Likes.liked?(someone, post)

    # end


    test "unlike a post" do
      poster = fake_user!()
      content = "here is an epic html post"
      attrs = %{post_content: %{html_body: content}}

      assert {:ok, post} =
               Posts.publish(current_user: poster, post_attrs: attrs, boundary: "local")

      some_account = fake_account!()
      someone = fake_user!(some_account)
      conn = conn(user: someone, account: some_account)

      assert {:ok, like} = Likes.like(someone, post)
      assert true == Likes.liked?(someone, post)

      next = "/feed/local"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert view
             |> element(".feed button.like")
             |> render_click()
             |> Floki.text() =~ "Like"

      assert false == Likes.liked?(someone, post)
    end


    test "liked activities dont have to show up in local feed" do
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      account = fake_account!()
      me = fake_user!(account)
      bob = fake_user!(account)
      html_body = "epic html message"
      # And bob creates a post with a 'public' boundary
      attrs = %{post_content: %{html_body: html_body}}
      assert {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")
      assert {:ok, like} = Likes.like(me, post)
      # When I login
      conn = conn(user: me, account: account)
      # And visit the local feed
      {:ok, view, _html} = live(conn, "/feed/local")
      liked = element(view, "[data-role=liked_by]")
      # view |> open_browser()
      refute has_element?(liked)
    end
  # test "As a user I want to see the activity total likes" do
  #   # Create alice user
  #   alice = fake_account!()
  #   |> fake_user!()
  #   # Create bob user
  #   account2 = fake_account!()
  #   bob = fake_user!(account2)
  #   # Create charlie user
  #   charlie = fake_account!()
  #   |> fake_user!()
  #   # bob follows alice
  #   Follows.follow(bob, alice)
  #   attrs = %{post_content: %{summary: "summary", name: "test post name", html_body: "<p>first post/p>"}}

  #   assert {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
  #   assert {:ok, like} = Likes.like(charlie, post)

  #   conn = conn(user: bob, account: account2)
  #   next = "/feed"
  #   {view, doc} = floki_live(conn, next)
  #   assert doc
  #     |> Floki.find("[data-id=feed] article")
  #     |> List.last
  #     |> Floki.text =~ "Like (1)"
  # end
end
