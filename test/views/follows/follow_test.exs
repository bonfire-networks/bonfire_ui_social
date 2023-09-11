defmodule Bonfire.Social.Follows.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Follows

  describe "follow" do
    test "when I click follow on someone's profile" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      my_account = fake_account!()
      me = fake_user!(my_account)

      conn = conn(user: me, account: my_account)
      next = Bonfire.Common.URIs.path(someone)
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert follow =
               view
               |> element("[data-id='follow']")
               |> render_click()

      assert true == Follows.following?(me, someone)

      # Note: the html returned by render_click isn't updated to show the change (probably because it uses ComponentID and pubsub) even though this works in the browser, so we wait for after pubsub events are received
      live_pubsub_wait(view)

      assert view
             |> render()
             ~> Floki.find("[data-id=unfollow]")
             |> Floki.text() =~ "Following"
    end
  end

  describe "unfollow" do
    test "when I click unfollow on someone's profile" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      my_account = fake_account!()
      me = fake_user!(my_account)

      assert {:ok, follow} = Follows.follow(me, someone)
      # assert true == Follows.following?(me, someone)

      conn = conn(user: me, account: my_account)
      next = Bonfire.Common.URIs.path(someone) |> info("path")
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)

      assert unfollow = view |> element("[data-id='unfollow']") |> render_click()
      assert false == Follows.following?(me, someone)

      live_pubsub_wait(view)

      assert view
             |> render()
             ~> Floki.find("[data-id=follow]")
             |> Floki.text() =~ "Follow"
    end
  end
end
