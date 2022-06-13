defmodule Bonfire.Social.Activities.CreatePost.Test do

  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows


  describe "create a post" do

    test "shows a confirmation flash message" do

      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/feed"
      {view, doc} = floki_live(conn, next) #|> IO.inspect

      assert posted = view
      |> form("#smart_input form")
      |> render_submit(%{"boundary_selected" => "public", "post" => %{"post_content" => %{"html_body" => content}}})
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
      {view, doc} = floki_live(conn, next) #|> IO.inspect

      assert view
      |> form("#smart_input form")
      |> render_submit(%{"boundary_selected" => "public", "post" => %{"post_content" => %{"html_body" => content}}})

      next = "/user"
      {view, doc} = floki_live(conn, next) #|> IO.inspect
      assert [feed] = Floki.find(doc, "[data-id=feed]")
      assert Floki.text(feed) =~ content
    end

    test "shows up right away" do

      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/feed"
      {view, doc} = floki_live(conn, next) #|> IO.inspect

      assert view
      |> form("#smart_input form")
      |> render_submit(%{"boundary_selected" => "public", "post" => %{"post_content" => %{"html_body" => content}}})

      # check if post appears instantly on home feed (with pubsub)
      live_pubsub_wait(view)

      assert view
      |> render()
      ~> Floki.find("[data-id=feed]")
      |> Floki.text() =~ content
    end

  end

end
