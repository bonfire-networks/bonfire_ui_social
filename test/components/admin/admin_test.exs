defmodule Bonfire.UI.Social.AdminTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Posts

  alias Bonfire.Common.Repo

  test "As an admin I want to create a new link to invite users to join an instance" do
  end

  test "As an admin I want to delete an existing link so it is not longer valid" do
  end

  test "As an admin I want to view the flagged activities feed" do
  end

  test "As an admin I want to remove a flagged activity " do
  end

  test "As an admin I want to ignore a flagged activity so that it
  does not show anymore in the flagged activities feed (it may shows
  in an archive feed?)" do
  end
end
