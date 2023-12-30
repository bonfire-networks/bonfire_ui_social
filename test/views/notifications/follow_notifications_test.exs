defmodule Bonfire.Social.Notifications.Follows.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "show" do
    test "when someone follows me in my notifications" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      me = fake_user!()
      assert {:ok, follow} = Follows.follow(me, someone)
      assert true == Follows.following?(me, someone)

      conn = conn(user: someone, account: some_account)
      next = "/notifications"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert feed = Floki.find(doc, ".feed")
      assert Floki.text(feed) =~ me.profile.name
      # FIXME
      assert Floki.text(feed) =~ "followed"
    end
  end

  describe "DO NOT show" do
    test "when I follow someone in my notifications" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      me = fake_user!()
      assert {:ok, follow} = Follows.follow(someone, me)
      assert true == Follows.following?(someone, me)

      conn = conn(user: someone, account: some_account)
      next = "/notifications"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      assert feed = Floki.find(doc, ".feed")
      refute Floki.text(feed) =~ me.profile.name
    end
  end
end
