defmodule Bonfire.UI.Social.Boundaries.BoundaryTest do

  use Bonfire.UI.Social.ConnCase

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

  test "Public: When I create an activity with the public boundary selected, it is visible in the federation, instance, home feed" do
  end

  test "Local instance: When I create an activity with the local boundary selected, it is visible in the instance and home feed" do
  end

  test "Mentions: When I create an activity with the mentions boundary selected,
  it is visible in the mentioned users inbox, mentioned users notification feed,
  mentioned users private feed" do
  end 
end
