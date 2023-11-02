defmodule Bonfire.Social.Activities.CreatePost.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  use Bonfire.Common.Utils
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

    test "shows up in feed right away" do
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


    test "has the correct permissions when replying" do
      alice = fake_user!("none")

    bob = fake_user!("contribute")

    attrs = %{
      post_content: %{summary: "summary", name: "test post name", html_body: "@#{bob.character.username} first post</p>"}
    }

    assert {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "mentions")


      content = "here is an epic html post"

      conn = conn(user: bob)

      next = "/post/#{id(op)}"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)
      # open_browser(view)
      live_pubsub_wait(view)

      assert _click =
               view
               |> element("[data-id=action_reply]")
               |> render_click()

               assert view
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "mentions",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

    conn2 = conn(user: alice)

      next = "/@#{bob.character.username}"
      # |> IO.inspect
      {:ok, feed, _html} = live(conn2, next)
      assert has_element?(feed, "[data-id=feed]", content)

      # WIP: does this test do what's expected?
    end
  end
end
