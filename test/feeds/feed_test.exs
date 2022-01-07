defmodule Bonfire.UI.Social.Feeds.FeedActivityTest do

  use Bonfire.UI.Social.ConnCase

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}
  alias Bonfire.Repo

  test "As a user I want to see up  to 10 activities when viewing a feed " do
  end

  test "As a user I want to click on the load more button to load more activities" do
  end

  test "As a user when I create a new activity, it appears instantly in the feed" do
  end

  test "Logged-in home activities feed shows the user inbox" do
  end

  test "Logged-out Home activities feed shows the instance outbox filtered by public boundary" do
  end

  test "Local feed shows the instance outbox filtered by local boundary" do
  end

  # Which activities? 
  test "Federation feed shows federated outbox" do
  end

  test "User timeline feed shows the user outbox" do
  end

  test "User posts feed only shows posts that are not replies" do
  end

  test "User likes feed only shows the like activities" do
  end

  test "Notification feed shows: likes, mentions, boosts, follows, reply activities" do
  end

  test "If Alice likes Bob's post, the liked activity should appear only in bob's notification feed" do
  end

  test "When Alice follows Bob, the followed activity appears only in bob's notification feed" do
  end
  
end