defmodule Bonfire.Social.Feeds.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}

  describe "Feeds UX" do
    test "As a user when I publish a new post I want to see it appearing at the beginning of the feed without refreshing the page" do
    end

    test "As a user I want to see the activity boundary" do
    end

    test "As a user I want to see if I already boosted an activity" do
    end

    test "As a user I want to see if I already liked an activity" do
    end

    test "As a user I want to see the context a message is replying to" do
    end

    test "When I click the reply button, I want to navigate to the thread page" do
    end

    test "When I click the boost button, I want the boosted activity to appear in the timeline without refreshing" do
    end

    test "When I click the like button, I want to see the liked activity without refreshing" do
    end

    test "As a user I want to click over the user avatar or name and navigate to their own profile page" do
    end

    test "As a user I want to click over a user mention within an activity and navigate to their own profile page" do
    end

    test "As a user I want to click over a link that is part of an activity body and navigate to that link" do
    end
  end
end
