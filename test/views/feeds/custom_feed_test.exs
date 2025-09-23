defmodule Bonfire.UI.Social.CustomFeedTest do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  use Bonfire.Common.Utils

  import Bonfire.Common.Simulation
  import Bonfire.Files.Simulation
  alias Bonfire.Files
  alias Bonfire.Files.ImageUploader

  alias Bonfire.Social.FeedActivities
  alias Bonfire.Social.FeedLoader
  alias Bonfire.Posts
  alias Bonfire.Messages
  alias Bonfire.Social.Activities
  alias Bonfire.Social.Objects
  alias Bonfire.Social.Likes

  alias Bonfire.Me.Users
  alias Bonfire.Me.Fake
  import Bonfire.Social.Fake
  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]
  import Tesla.Mock

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)
    bob = fake_user!(account)

    # Alice creates a post
    alice_post_content = "This is Alice's post that I will like"
    alice_post_attrs = %{post_content: %{html_body: alice_post_content}}

    {:ok, alice_post} =
      Posts.publish(current_user: alice, post_attrs: alice_post_attrs, boundary: "public")

    # Bob creates a post
    bob_post_content = "This is Bob's post that I won't like"
    bob_post_attrs = %{post_content: %{html_body: bob_post_content}}

    {:ok, bob_post} =
      Posts.publish(current_user: bob, post_attrs: bob_post_attrs, boundary: "public")

    # Me likes Alice's post
    {:ok, like} = Likes.like(me, alice_post.id)

    conn = conn(user: me, account: account)

    {:ok,
     conn: conn,
     account: account,
     alice: alice,
     bob: bob,
     me: me,
     alice_post: alice_post,
     bob_post: bob_post,
     alice_post_content: alice_post_content,
     bob_post_content: bob_post_content}
  end

  test "create custom feed preset with day time limit", %{conn: conn, me: me} do
    # Create a custom feed with time limit set to day
    preset_name = "Daily Activities"
    preset_description = "Posts from the last day"

    conn
    |> visit("/feed")
    # |> PhoenixTest.open_browser()
    # Set time limit to Last Day by clicking dropdown and selecting option
    |> click_link("Last Day")

    # Click on Save button to open modal
    |> click_button("Save")

    # Fill in the form fields
    |> within("form#form_create_feed_preset", fn session ->
      session
      |> fill_in("Feed title", with: preset_name)
    end)

    # Submit the form
    |> click_button("Save feed")
    # |> PhoenixTest.open_browser()
    # The feed should be saved and should appear in the navigation
    |> visit("/settings/user/feeds")

    # Check that our new feed is listed
    |> assert_has_or_open_browser("div", text: preset_name)
  end

  test "custom feed preset maintains time limit settings for saved presets", %{
    conn: conn,
    me: me,
    alice_post: alice_post,
    bob_post: bob_post
  } do
    # First, create a feed preset with Day time limit
    preset_name = "daily"
    Config.put([Bonfire.UI.Social.FeedLive, :time_limit], 0)
    # Create the feed preset in a separate visit/session
    conn
    |> visit("/feed")
    # |> PhoenixTest.open_browser()
    # Set time limit to Last Day
    # |> click_button("All time")
    |> click_link("Last Day")
    # Save the feed preset
    |> click_button("Save")
    |> within("form#form_create_feed_preset", fn session ->
      session
      |> fill_in("Feed title", with: preset_name)
    end)
    |> click_button("Save feed")

    # Verify it was created by checking in settings
    |> visit("/settings/user/feeds")
    |> assert_has_or_open_browser("div", text: preset_name)

    # Now in a new session, check that the time limit is preserved
    # First visit the feed with the custom preset
    |> visit("/feed/#{preset_name}")
    # |> PhoenixTest.open_browser()
    # Check if we can see the time limit is set to Last Day
    |> assert_has("label", text: "Last Day")
    # Now go to a different feed and verify the time limit reverts to default
    |> visit("/feed/local")
    # |> PhoenixTest.open_browser()
    |> assert_has("label", text: "All time")
  end
end
