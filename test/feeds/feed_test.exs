defmodule Bonfire.UI.Social.Feeds.FeedTest do

  use Bonfire.UI.Social.ConnCase
  # alias Bonfire.Social.Fake
  alias Bonfire.Social.{Boosts, Likes, Follows, Posts}


  describe "Feed Activity/Object Preview UX" do

    # test "As a user I dont want to see the load more button if there are less than 11 activities" do
    #   total_posts = 10
    #   # Create alice user
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   # Create bob user
    #   account2 = fake_account!()
    #   bob = fake_user!(account2)
    #   # bob follows alice
    #   Follows.follow(bob, alice)
    #   attrs = %{circles: [:local], post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

    #   for n <- 1..total_posts do
    #     assert {:ok, post} = Posts.publish(alice, attrs)
    #   end

    #   assigns = Bonfire.Social.Web.Feeds.BrowseLive.default_feed(bob) #|> IO.inspect

    #   assert doc = render_component(Bonfire.UI.Social.FeedLive, assigns)
    #   assert Floki.find(doc, "#load_more") == []
    # end

    # test "As a user I want to see the load more button if there are more than 11 activities" do
    #   total_posts = 11
    #   # Create alice user
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   # Create bob user
    #   account2 = fake_account!()
    #   bob = fake_user!(account2)
    #   # bob follows alice
    #   Follows.follow(bob, alice)
    #   attrs = %{circles: [:guest], post_content: %{summary: "summary", name: "test post name", html_body: "<p>epic html message</p>"}}

    #   for n <- 1..total_posts do
    #     assert {:ok, post} = Posts.publish(alice, attrs)
    #   end

    #   assigns = Bonfire.Social.Web.Feeds.BrowseLive.default_feed(bob) #|> IO.inspect

    #   assert doc = render_component(Bonfire.UI.Social.FeedLive, assigns)
    #   assert Floki.find(doc, "#load_more") != []
    # end



  end

end
