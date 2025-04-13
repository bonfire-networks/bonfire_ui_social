defmodule Bonfire.UI.Social.Feeds.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts
  import Tesla.Mock

  setup do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(account)

    conn = conn(user: me, account: account)

    mock(fn
      %{method: :get, url: "https://windsurf.run/elixir-phoenix-cursor-rules"} ->
        "<title>Test HTML</title>"
    end)
    

    {:ok, conn: conn, account: account, alice: alice, me: me}
  end

  @tag :todo
  test "replies that appear via pubsub should show the reply_to", %{
    conn: conn,
    me: me,
    alice: alice
  } do
    Follows.follow(me, alice)

    # then alice creates a post
    html_body = "epic html message"
    attrs = %{post_content: %{html_body: html_body}}
    {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    # alice creates a reply
    reply_content = "this is reply 112"

    attrs_reply = %{
      post_content: %{
        html_body: reply_content
      },
      reply_to_id: post.id
    }

    {:ok, reply} = Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")

    # visit the feed and check for the reply
    conn
    |> visit("/feed/local")
    # Wait for pubsub to deliver the reply
    # |> Process.sleep(500)
    |> assert_has("[data-id=feed] article", text: reply_content)
  end

  @tag :todo
  test "images/attachments should be hidden behind CW even when the initial activity appears via pubsub",
       %{conn: conn, me: me} do
    # Create a post with a content warning and media attachment
    html_body = "epic html message"
    cw = "new cw"

    attrs = %{
      post_content: %{
        html_body: html_body,
        content_warning: cw
      },
      # Simulate uploaded media - implementation will depend on your app's media handling
      uploaded_media: [%{url: "https://example.com/image.jpg", type: "image"}]
    }

    # Publish the post
    {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

    # Visit the feed and verify CW is hiding content
    conn
    |> visit("/feed/local")
    |> assert_has("[data-role=cw]", text: cw)
    |> refute_has("[data-id=object_body]:visible")
    |> refute_has("[data-id=media_list]:visible")

    # Click the "Show more" button
    |> click_button(".show_more_toggle_action", "Show more")

    # Verify content is now visible
    |> assert_has("[data-id=object_body]:visible")
    |> assert_has("[data-id=media_list]:visible")
  end

  describe "Feeds UX" do
    @tag :todo
    test "As a user when I publish a new post I want to see it appearing at the beginning of the feed without refreshing the page",
         %{conn: conn, me: me} do
      # Go to local feed
      conn
      |> visit("/feed/local")

      # Create a new post using the form in the UI
      |> fill_in("#smart_input", with: "This is a test post")
      |> click_button("[data-action=submit]", "Post")

      # Check that post appears at the beginning of the feed without page refresh
      |> assert_has("[data-id=feed] article:first-child [data-id=object_body]",
        text: "This is a test post"
      )
    end

    test "As a user I want to see the activity's boundary", %{conn: conn, me: me} do
      # Create a post with a specific boundary
      Process.put(:feed_live_update_many_preload_mode, :inline)
      html_body = "Post with local boundary"
      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "local")

      # Visit the feed and verify boundary is displayed
      conn
      |> visit("/feed/local")
      |> assert_has("[data-scope=local-boundary-set]", text: "Local")
    end

    @tag :skip
    test "As a user I want to see what a post is replying to", %{conn: conn, me: me, alice: alice} do
      # Create an original post
      original_content = "Original post content"
      attrs = %{post_content: %{html_body: original_content}}
      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

      # Create a reply to the original post
      reply_content = "This is a reply to the original post"

      attrs_reply = %{
        post_content: %{
          html_body: reply_content
        },
        reply_to_id: post.id
      }

      {:ok, reply} = Posts.publish(current_user: me, post_attrs: attrs_reply, boundary: "public")

      # Visit the reply in its thread context
      conn
      |> visit("/post/#{post.id}#comment_#{reply.id}")

      # Verify that we can see both the reply and what it's replying to
      |> assert_has("[data-id=object_body]", text: original_content)
      |> assert_has("[data-id=object_body]", text: reply_content)
    end

    @tag :todo
    test "When I click the boost button, I want the boosted activity to appear in the timeline without refreshing",
         %{conn: conn, me: me, alice: alice} do
      Follows.follow(me, alice)

      # alice creates a post
      html_body = "Post to be boosted"
      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # visit the feed and boost the post
      conn
      |> visit("/feed/local")
      |> click_button("[data-id=boost_action]")

      # check that the boosted post appears in the timeline with boost indication
      # Original post and boosted copy
      |> assert_has("[data-id=feed] article", count: 2)

      # Could check for specific boosted indicator depending on UI implementation
    end

    test "As a user I want to click over the user avatar or name and navigate to their own profile page",
         %{conn: conn, me: me} do
      # Using the username from the HTML sample
      username = "test"
      alice = fake_user!(username)
      # alice creates a post
      html_body = "Post from test user"
      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # visit the feed and click on user avatar
      conn
      # |> visit("/feed/local")
      # |> click_link("[data-id=subject_avatar]")
      # |> assert_path("/character/test")

      # go back to feed and click on username instead
      |> visit("/feed/local")
      |> click_link("[data-id=subject_name]", "test")

      # verify we're on the user's profile page again
      |> assert_path("/@test")
    end

    test "As a user I want to click over a user mention within an activity and navigate to their own profile page",
         %{conn: conn, me: me} do
      mayel = fake_user!("mayel")

      # Create a post with a mention
      html_body =
        "<p> <a href=\"/character/mayel\">@mayel</a> here is a link <a href=\"https://example.com\">example.com</a></p>"

      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

      # visit the feed and click on the mention
      conn
      |> visit("/feed/local")
      |> click_link("@mayel")

      # verify we're on the mentioned user's profile page
      |> assert_path("/@mayel")
    end

    test "As a user I want to click over a link that is part of an activity body and navigate to that link",
         %{conn: conn, me: me} do
      # Create a user# Create a post with a link
      html_body = "<p>Check out this link https://windsurf.run/elixir-phoenix-cursor-rules</p>"
      attrs = %{post_content: %{html_body: html_body}}
      {:ok, post} = Posts.publish(current_user: me, post_attrs: attrs, boundary: "public")

      # Visit the feed
      conn
      |> visit("/feed/local")

      # Check if the link is visible in the post body
      |> assert_has("a[href*='windsurf.run']")

      # Note: We can't actually test clicking and navigating to external links in a feature test
      # But we can verify the link has the correct attributes
      |> assert_has("a[href='https://windsurf.run/elixir-phoenix-cursor-rules']")

      # We could also check the media preview card
      |> assert_has_or_open_browser("[data-id=media_link]")
      |> assert_has("[data-id=media_title]", text: "Windsurf Directory")
    end
  end
end
