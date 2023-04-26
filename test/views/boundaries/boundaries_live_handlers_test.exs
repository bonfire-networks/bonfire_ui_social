defmodule Bonfire.Social.Activities.BoundariesLiveHandlerTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Follows
  import Bonfire.Common.Enums
  alias Bonfire.Boundaries.{Circles, Acls, Grants}

  describe "Basic Circle actions" do
    test "Create a circle works" do
      account = fake_account!()
      me = fake_user!(account)

      conn = conn(user: me, account: account)

      next = "/boundaries/circles"
    end

    test "Add a user to a circle works" do
    end

    test "Remove a user from a circle works" do
    end

    test "Edit Settings to a circle works" do
    end
  end

  describe "Basic Boundaries actions" do
    test "Create a boundary works" do
    end

    test "Add a user and assign a role to a boundary works" do
    end

    test "Remove a user from a boundary works" do
    end

    test "Add a circle and assign a role to a boundary works" do
    end

    test "Remove a circle from a boundary works" do
    end

    test "Edit a role in a boundary works" do
    end

    test "Edit Settings to a boundary works" do
    end
  end
end
