defmodule Bonfire.UI.Social.BrowsingTest do
  use Bonfire.UI.Social.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Social.Posts


  test "Alice boosts Bob post, navigate to local feed with alice, the boosted activity does not show the subject (alice)" do
    # it works on other feeds, but not on local feed

  end

  test "Alice navigate to bob profile, try to add bob in a circle, the list of circles is empty even if alice has circles" do

  end

  test "Alice navigate to bob profile, try to add bob in a circle, creates a new circle and add bob, but the circles does not exist later" do

  end

  test "When unfollowing a followed user in their profile, the button breaks and shows a follow button and within an unfollow button" do

  end

  test "I cannot add a circle when customising the boundaries in composer (it is not added to the list)" do

  end

  test "Click to customise the public boundary -> edit the local users circle to read -> click done -> click to customise the local boundary -> the boundary is wrong)" do
    # Even if I've already edited a boundary, if I press on the customise button again, the boundary should reset to the one I've just decided to edit -> the local one in this case
  end

  # UI
  test "In the navigation sidebar, clicking on Favourites does not highlight the link" do

  end

  test "Navigate to a user profile -> click to send a DM -> the composer with the right field to send DM  shows up -> click on compose on the left sidebar -> the composer does not default to the normal composer (with boundaries etc.)" do

  end

  test "editing the circle name does not update instantly" do

  end

  test "unlinking a post from the favourites feed does not remove it instantly" do

  end

  test "even if the likes feed has 0 items, it shows the 'show older activities' button instead of the empty message" do

  end

  test "editing the CW of a post doesn't update it" do

  end

end
