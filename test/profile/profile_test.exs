defmodule Bonfire.UI.Social.Profile.ProfileTest do

  use Bonfire.UI.Social.ConnCase, async: true
  # alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}


  describe "Profile: Check if the profile hero section displays all the information correctly " do

    test "As a user I want to see the user background image" do
    end

    test "As a user I want to see the user avatar image" do
    end

    test "As a user I want to see the user name" do
    end

    test "As a user I want to see the user preferred username" do
    end

    test "As a user I want to see the user bio" do
    end

    test "If the user bio contains links I want to be able to navigate to that link" do
    end

    test "As a user I want to see user total followers" do
    end

    test "As a user I want to see user total following" do
    end

    test "As a user I want to see user location" do
    end

    test "As a user I want to see user link" do
    end

    test "If I navigate to my own profile, I want to see the settings button" do
    end

    test "If I navigate to a user that I do not follow profile, I want to see the follow button" do
    end

    test "If I click to follow, I want to see the button label changing from follow to unfollow" do
    end

    test "If I navigate to a user that I do not follow profile, I want to see the unfollow button" do
    end

    test "If I click to unfollow, I want to see the button label changing from unfollow to follow" do
    end

  end

  describe "Profile: Navigation" do

    test "As a user, when I navigate to a user profile, I should see the timeline tab as the active default" do
    end

    test "As a user when I click on Timeline link, I want to see the user outbox" do
    end

    test "As a user, when I navigate to a user profile, If I click on posts link I should see only the posts activities" do
    end

    test "As a user when I navigate to a user profile, If I click on boosts link, I should see only user boosted activities" do
    end

    test "As a user when I navigate to a user profile, If I click on liked link, I should see only user liked activities" do
    end

  end

  describe "Profile: Followers and Following tabs" do
    test "When I click on followers link, I want to see the paginated list of followers" do
    end
    test "When I click on following link, I want to see the paginated list of following" do
    end
  end


end
