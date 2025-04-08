defmodule Bonfire.UI.Social.Notifications.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "show" do
    # test "with account" do
    #   account = fake_account!()
    #   conn = conn(account: account)
    #   next = "/notifications"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [_] = Floki.find(doc, "[data-id=feed]")
    # end

    @tag :skip_ci
    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/notifications"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      refute [] == Floki.find(doc, "[data-id=feed]")
    end
  end

  describe "DO NOT show" do
    test "when not logged in" do
      conn = conn()
      conn = get(conn, "/notifications")
      assert redirected_to(conn) =~ "/login"
    end

    # test "with account only" do
    #   account = fake_account!()
    #   conn = conn(account: account)
    #   next = "/notifications"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [] == Floki.find(doc, "[data-id=feed]") # TODO: what to show in this case?
    # end
  end
end
