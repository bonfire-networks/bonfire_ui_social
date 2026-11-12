defmodule Bonfire.UI.Social.Threads.NestedLoadMoreRepliesTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
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
         %{conn: conn, alice: alice, bob: bob, original_post: original_post} do
      load_more_replies_step = 2
      max_depth = 2
      depth = 7

      Process.put([:bonfire, :thread_default_max_depth], max_depth)

      assert max_depth == Bonfire.Social.Threads.LiveHandler.max_depth(current_user: bob)

      # Create a nested chain of X replies
      replies = create_reply_chain(alice, original_post.id, depth, "Nested reply")

      # Visit the discussion and check for load more replies button
      conn
      |> visit("/discussion/#{original_post.id}")
      # |> PhoenixTest.open_browser()
      |> assert_has("[data-id='comment']", count: max_depth)
      |> assert_has("[data-id='load_more_replies']")
      # match the "more repl" stem so it works whether the button reads "N more replies" (plural) or
      # "1 more reply" (singular — as on the final click, when only one reply remains beyond the depth)
      |> click_button("[data-id='load_more_replies']", "more repl")
      # |> PhoenixTest.open_browser()
      #  NOTE: it seems to load one more than max_depth in load_more_replies 
      |> assert_has("[data-id='comment']", count: max_depth + load_more_replies_step + 1)
      # |> PhoenixTest.open_browser()
      # match the "more repl" stem so it works whether the button reads "N more replies" (plural) or
      # "1 more reply" (singular — as on the final click, when only one reply remains beyond the depth)
      |> click_button("[data-id='load_more_replies']", "more repl")
      |> assert_has("[data-id='comment']", count: depth)
    end

    test "a guest gets a plain link to the reply's own page for the replies beyond the max depth, and it shows them",
         %{original_post: original_post} do
      Process.put([:bonfire, :thread_default_max_depth], 2)
      # guests get 1.4× the max depth
      guest_depth = Bonfire.Social.Threads.LiveHandler.max_depth(current_user: nil)
      assert guest_depth == 3

      replies =
        create_reply_chain(original_post.created.creator, original_post.id, 7, "Nested reply")

      deepest_shown = Enum.at(replies, guest_depth - 1)

      conn()
      |> visit("/discussion/#{original_post.id}")
      |> assert_has("[data-id='comment']", count: guest_depth)
      |> refute_has("[data-id='load_more_replies']")
      |> assert_has(
        "a[href='/discussion/#{original_post.id}/reply/#{guest_depth}/#{deepest_shown.id}']",
        text: "more repl"
      )
      |> refute_has("a[href*='remote_interaction']", text: "more repl")
      |> click_link("more repl")
      |> assert_has("[data-id='comment']", text: "Nested reply level #{guest_depth + 1}")
    end

    test "a guest keeps following the link one max depth at a time down a deep chain",
         %{original_post: original_post} do
      Process.put([:bonfire, :thread_default_max_depth], 2)
      guest_depth = Bonfire.Social.Threads.LiveHandler.max_depth(current_user: nil)
      assert guest_depth == 3

      replies = create_reply_chain(original_post.created.creator, original_post.id, 10, "Chain")

      link = fn n ->
        "a[href='/discussion/#{original_post.id}/reply/#{n}/#{Enum.at(replies, n - 1).id}']"
      end

      conn()
      |> visit("/discussion/#{original_post.id}")
      |> assert_has("[data-id='comment']", count: 3)
      |> assert_has(link.(3), text: "more repl")
      |> click_link(link.(3), "more repl")
      # the reply, its ancestors, and one max depth below it
      |> assert_has("[data-id='comment']", count: 6)
      |> assert_has("[data-id='comment']", text: "Chain level 6")
      |> refute_has("[data-id='comment']", text: "Chain level 7")
      |> refute_has(link.(3))
      |> assert_has(link.(6), text: "more repl")
      |> click_link(link.(6), "more repl")
      |> assert_has("[data-id='comment']", count: 9)
      |> assert_has("[data-id='comment']", text: "Chain level 9")
      |> refute_has("[data-id='comment']", text: "Chain level 10")
      |> assert_has(link.(9), text: "more repl")
      |> click_link(link.(9), "more repl")
      |> assert_has("[data-id='comment']", count: 10)
      |> assert_has("[data-id='comment']", text: "Chain level 10")
      # nothing is left under the last reply, so no next link
      |> refute_has(link.(9))
      |> refute_has("a[href*='/discussion/#{original_post.id}/reply/10/']")
    end

    test "on one branch's reply page, the other branches keep their own link",
         %{original_post: original_post} do
      Process.put([:bonfire, :thread_default_max_depth], 2)
      creator = original_post.created.creator

      branch_a = create_reply_chain(creator, original_post.id, 7, "Alpha")
      branch_b = create_reply_chain(creator, original_post.id, 7, "Beta")
      a3 = Enum.at(branch_a, 2)
      b3 = Enum.at(branch_b, 2)

      conn()
      |> visit("/discussion/#{original_post.id}/reply/3/#{a3.id}")
      |> assert_has("[data-id='comment']", text: "Alpha level 6")
      |> refute_has("[data-id='comment']", text: "Beta level 4")
      |> assert_has("a[href='/discussion/#{original_post.id}/reply/3/#{b3.id}']",
        text: "more repl"
      )
      |> assert_has(
        "a[href='/discussion/#{original_post.id}/reply/6/#{Enum.at(branch_a, 5).id}']"
      )
      |> refute_has("a[href='/discussion/#{original_post.id}/reply/3/#{a3.id}']")
    end

    test "a reply under the focused one that guests can't see stays hidden on the reply page",
         %{original_post: original_post} do
      Process.put([:bonfire, :thread_default_max_depth], 2)
      creator = original_post.created.creator

      shown = create_reply_chain(creator, original_post.id, 4, "Visible")
      three = Enum.at(shown, 2)

      {:ok, _hidden} =
        Posts.publish(
          current_user: creator,
          post_attrs: %{
            post_content: %{
              summary: "summary",
              name: "Hidden reply",
              html_body: "<p>Hidden body</p>"
            },
            reply_to_id: three.id
          },
          boundary: "local"
        )

      conn()
      |> visit("/discussion/#{original_post.id}/reply/3/#{three.id}")
      |> assert_has("[data-id='comment']", text: "Visible level 4")
      |> refute_has("[data-id='comment']", text: "Hidden reply")
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
