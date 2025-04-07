defmodule Bonfire.UI.Social.Threads.NestedLoadMoreRepliesTest do
  use Bonfire.UI.Social.ConnCase, async: true
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  describe "Load More Replies in Nested Threads" do
    setup do
      # Create alice user (author of all posts)
      account = fake_account!()
      alice = fake_user!(account)

      # Create bob user (viewer of the thread)
      account2 = fake_account!()
      bob = fake_user!(account2)

      # Bob follows Alice so he can see her posts
      Follows.follow(bob, alice)

      # Standard post attrs
      attrs = %{
        post_content: %{
          summary: "summary",
          name: "Original post",
          html_body: "<p>Original post body</p>"
        }
      }

      # Create the original post
      {:ok, original_post} =
        Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # Return setup data
      {:ok,
       conn: conn(user: bob, account: account2),
       alice: alice,
       bob: bob,
       original_post: original_post}
    end

    test "should display load more replies button when there are nested replies beyond max depth, and clicking load more replies button should show more nested replies",
         %{conn: conn, alice: alice, original_post: original_post} do
      load_more_replies_step = 2
      max_depth = 2
      depth = 7

      Process.put([:bonfire, :thread_default_max_depth], max_depth)

      assert max_depth == Bonfire.Social.Threads.LiveHandler.max_depth()

      # Create a nested chain of X replies
      replies = create_reply_chain(alice, original_post.id, depth, "Nested reply")

      # Visit the discussion and check for load more replies button
      conn
      |> visit("/discussion/#{original_post.id}")
      # |> PhoenixTest.open_browser()
      |> assert_has("[data-id='comment']", count: max_depth)
      |> assert_has("[data-id='load_more_replies']")
      |> click_button("[data-id='load_more_replies']", "more replies")
      # |> PhoenixTest.open_browser()
      #  NOTE: it seems to load one more than max_depth in load_more_replies 
      |> assert_has("[data-id='comment']", count: max_depth + load_more_replies_step + 1)
      # |> PhoenixTest.open_browser()
      |> click_button("[data-id='load_more_replies']", "more replies")
      |> assert_has("[data-id='comment']", count: depth)
    end

    test "should handle multiple levels of load more replies",
         %{conn: conn, alice: alice, original_post: original_post} do
      Process.put([:bonfire, :thread_default_max_depth], 2)

      # Create a deep thread with branches
      main_replies = create_reply_chain(alice, original_post.id, 3, "Main branch")

      # Create a sibling branch
      sibling_replies = create_reply_chain(alice, original_post.id, 3, "Sibling nested")

      # Visit the discussion page
      session =
        conn
        |> visit("/discussion/#{original_post.id}")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id='load_more_replies']")
        # Should have multiple load more buttons
        |> assert_has("[data-id='load_more_replies']", count: 2)

      # TODO: not sure how to click on the 1st button with PhoenixTest
      # # First click on first load_more_replies button
      # session = 
      # session
      # |> click_button("[data-id='load_more_replies']:first-of-type", "more replies")
      # |> assert_has("html_body", text: "Main branch level 3") # Should show level 3 reply

      # # Then click on second load_more_replies button 
      # session
      # |> click_button("[data-id='load_more_replies']", "more replies")
      #   |> assert_has("html_body", text: "Sibling branch level 3") # Should eventually show deep nested replies
    end
  end

  # Helper to create a reply
  defp create_reply(user, parent_id, name) do
    Posts.publish(
      current_user: user,
      post_attrs: %{
        post_content: %{
          summary: "summary",
          name: name,
          html_body: "<p>#{name} body</p>"
        },
        reply_to_id: parent_id
      },
      boundary: "public"
    )
  end

  # Helper to create a chain of nested replies with specified depth
  # Returns a list of replies in order from parent to deepest child
  defp create_reply_chain(user, start_parent_id, depth, prefix \\ "Reply") do
    Enum.reduce(1..depth, {[], start_parent_id}, fn level, {replies, parent_id} ->
      name = "#{prefix} level #{level}"
      {:ok, reply} = create_reply(user, parent_id, name)
      {replies ++ [reply], reply.id}
    end)
    # Return just the list of replies
    |> elem(0)
  end
end
