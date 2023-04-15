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

      next = "/feed"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert posted =
               view
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

      next = "/feed"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

      next = "/user"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert [feed] = Floki.find(doc, "[data-id=feed]")
      assert Floki.text(feed) =~ content
    end

    test "shows up right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      next = "/feed"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

      # check if post appears instantly on home feed (with pubsub)
      live_pubsub_wait(view)

      assert view
             |> render()
             |> Floki.parse_document()
             #  |> debug("doc")
             ~> Floki.find("[data-id=feed]")
             |> debug("feed contents")
             |> Floki.text() =~ content
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
      reply_to = %{reply_to_id: post.id, thread_id: post.id}
      attrs_reply = %{
        post_content: %{
          summary: "summary",
          name: "name 2",
          html_body: "<p>epic html message</p>"
        },
        reply_to_id: post.id
      }
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")
      # then I log in and reply to it
      # assert view
      # |> form("#smart_input form")
      # |> render_submit(%{
        #   "to_boundaries" => "public",
        #   "reply_to" => %{"reply_to_id" => post.id},
        #   "post" => %{
          #   "post_content" => %{"html_body" => "reply to alice"}}
          # })


          # im not sure if lvie_pubsub_wait is enough to wait for asyync loading of the reply
          # so we wait a bit more
      conn = conn(user: me, account: account)
      {:ok, view, _html} = live(conn, "/feed/local")
      live_pubsub_wait(view)

      # we wait a bit more
      view |> open_browser()
      # not sure why the reply is not showingup even after refreshing the page, maybe the reply_to is not in the right place?
    end

    test "images/attachments aren't hidden behind CW when the initial activity appears via pubsub" do
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
        post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")
      {:ok, view, _html} = live(conn, "/feed/local")
      live_pubsub_wait(view)
      # we wait a bit more
      view |> open_browser()

    end

  end
end
