defmodule Bonfire.Social.Activities.CreatePost.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows
  alias Bonfire.Files.Test
  # FIXME: path
  @icon_file %{
    path: Path.expand("fixtures/150.png", __DIR__),
    filename: "150.png"
  }

  describe "create a post" do
    test "shows a confirmation flash message" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/settings"
      {:ok, view, _html} = live(conn, next)
      # open_browser(view)

      # wait for persistent smart input to be ready
      live_pubsub_wait(view)

      assert posted =
<<<<<<< HEAD
               html
=======
              view
>>>>>>> 2f436250 (https://github.com/bonfire-networks/bonfire-app/issues/699)
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "public",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

      # |> Floki.text() =~ "Posted"

      live_pubsub_wait(view)
      assert [ok] = find_flash(posted)
      assert ok |> Floki.text() =~ "Posted"
    end

    test "shows up on my profile timeline" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/settings"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)
      # open_browser(view)
      live_pubsub_wait(view)

      assert posted =
               view
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "public",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

      next = "/user"
      # |> IO.inspect
      {:ok, profile, _html} = live(conn, next)
      assert has_element?(profile, "[data-id=feed]", content)
    end

    test "shows up right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      next = "/feed"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)

      assert view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

      # check if post appears instantly on home feed (with pubsub)
      live_pubsub_wait(view)

      assert has_element?(view, "[data-id=feed]", content)
    end

    test "replies that appear via pubsub should show the reply_to" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      alice = fake_user!(account)
      Follows.follow(me, alice)
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)

      # then alice creates a post
      html_body = "epic html message"
      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")
      # reply_to = %{reply_to_id: post.id, thread_id: post.id}

      reply_content = "this is reply 112"

      attrs_reply = %{
        post_content: %{
          html_body: reply_content
        },
        reply_to_id: post.id
      }

      {:ok, post} =
        Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")



      # im not sure if live_pubsub_wait is enough to wait for asyync loading of the reply
      # so we wait a bit more
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")

      live_pubsub_wait(view)
      #  open_browser(view)
      assert has_element?(view, "[data-id=feed]", reply_content)

      # view |> open_browser()
    end

    test "images/attachments should be hidden behind CW even when the initial activity appears via pubsub" do
      # create a bunch of users
      account = fake_account!()
      me = fake_user!(account)
      feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
      # then I log in and go to my local feed
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")
      # and create a post
      html_body = "epic html message"

      attrs = %{
        # uploaded_media: [], WIP: Not sure how to add a fake media
        post_content: %{html_body: html_body}
      }

      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      {:ok, view, _html} = live(conn, "/feed/local")
      live_pubsub_wait(view)

      # TODO!

      # we wait a bit more
      # view |> open_browser()
    end
  end
end
