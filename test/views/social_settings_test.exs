defmodule Bonfire.UI.Social.SettingsTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  use Mneme
  import Bonfire.Files.Simulation

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Common.Config
  alias Bonfire.Common.Enums

  @moduletag :mneme

  setup_all do
    orig1 = Config.get(:pagination_hard_max_limit)
    orig2 = Config.get(:default_pagination_limit)

    Config.put(:pagination_hard_max_limit, 5)
    Config.put(:default_pagination_limit, 5)

    on_exit(fn ->
      Config.put(:pagination_hard_max_limit, orig1)
      Config.put(:default_pagination_limit, orig2)
    end)
  end

  describe "Behaviours" do
    test "Feed activities" do
      Config.put(:pagination_hard_max_limit, 10)
      Config.put(:default_pagination_limit, 10)

      # create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # create bob user
      bob = fake_user!(account)

      # create post by alice
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # create a reply by bob
      alice_post = %{
        post_content: %{
          html_body: "reply"
        },
        reply_to_id: post.id
      }

      assert {:ok, post_reply} =
               Posts.publish(current_user: bob, post_attrs: alice_post, boundary: "public")

      # boost the post
      assert {:ok, boost} = Boosts.boost(bob, post_reply)
      # bob follows alice
      assert {:ok, follow} = Follows.follow(alice, bob)

      assert {:ok, op2} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # navigate to the settings page
      conn = conn(user: alice, account: account)

      # Visit the settings page
      conn = visit(conn, "/settings/user/preferences/behaviours")

      # Toggle boosts setting - uncheck the toggle
      conn =
        within(conn, "form[data-scope=boosts]", fn c ->
          c = uncheck(c, "Boosts")
          c
        end)

      # Toggle replies setting - uncheck the toggle
      conn =
        within(conn, "form[data-scope=replies]", fn c ->
          c = uncheck(c, "Replies")
          c
        end)

      # Toggle outbox setting - uncheck the toggle
      conn =
        within(conn, "form[data-scope=outbox]", fn c ->
          c = uncheck(c, "My own activities")
          c
        end)

      # Visit the feed and check results
      conn =
        visit(conn, "/feed/local")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id=feed] article", text: "first post")
        |> refute_has("[data-id=feed] article", text: "reply")
        |> refute_has("[data-id=feed] article", text: "boosted")

      conn = visit(conn, "/settings/user/preferences/behaviours")

      # Toggle boosts setting - uncheck the toggle
      conn =
        within(conn, "form[data-scope=boosts]", fn c ->
          c = check(c, "Boosts")
          c
        end)

      # Toggle replies setting - uncheck the toggle
      conn =
        within(conn, "form[data-scope=replies]", fn c ->
          c = check(c, "Replies")
          c
        end)

      conn =
        within(conn, "form[data-scope=outbox]", fn c ->
          c = check(c, "My own activities")
          c
        end)

      conn =
        visit(conn, "/feed/local")
        # |> PhoenixTest.open_browser()
        |> assert_has("[data-id=feed] article", text: "first post")
        |> assert_has("[data-id=feed] article", text: "reply")
        |> assert_has("[data-id=feed] article", text: "boosted")
    end

    test "default feed" do
      # create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # create bob user
      bob = fake_user!(account)

      # create post by alice
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # create a post by bob
      attrs = %{
        post_content: %{html_body: "bob post"}
      }

      assert {:ok, p} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # Connect as Alice
      conn = conn(user: alice, account: account)

      # Check feed initially shows alice's post first
      conn =
        visit(conn, "/feed")
        # |> PhoenixTest.open_browser()
        |> assert_has("article", text: "alice post")

      # Change default feed to local
      conn = visit(conn, "/settings/user/preferences/behaviours")

      conn =
        within(conn, "form[data-scope=set_default_feed]", fn c ->
          # Select "Local" from dropdown - use the actual select element id
          c = PhoenixTest.select(c, "Set default feed", option: "Local")
          # No need to click submit as the form has phx-change event
          c
        end)

      # |> PhoenixTest.open_browser()

      # Visit feed and check bob's post is shown first
      conn =
        visit(conn, "/feed")
        # |> PhoenixTest.open_browser()
        |> assert_has("article", text: "bob post")
    end

    test "feed default sort" do
      # create 2 users
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)

      # create a post that has 2 replies
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      attrs = %{
        post_content: %{html_body: "reply 1"},
        reply_to_id: post.id
      }

      assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      attrs = %{
        post_content: %{html_body: "reply 2"},
        reply_to_id: post.id
      }

      assert {:ok, p2} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # create a post that has 2 likes
      assert {:ok, like} = Likes.like(alice, p1)
      assert {:ok, like} = Likes.like(bob, p1)

      # create a post that has 2 boosts
      assert {:ok, boost} = Boosts.boost(alice, p2)
      assert {:ok, boost} = Boosts.boost(bob, p2)

      conn = conn(user: alice, account: account)

      # Check initial post ordering (newest first)
      conn = visit(conn, "/feed/local")
      assert_has(conn, "article", text: "reply 2")

      conn = visit(conn, "/settings/user/preferences/behaviours")

      # Change sort to likes
      conn =
        within(conn, "form[data-scope=reactions_sort]", fn c ->
          # Select "Number of likes" from dropdown
          c = PhoenixTest.select(c, "Sort by", option: "Amount of likes")
          # Submit the form
          c
        end)

      # Check most liked post is first
      conn = visit(conn, "/feed/local")
      assert_has(conn, "article", text: "reply 1")

      # Change sort to replies
      conn = visit(conn, "/settings/user/preferences/behaviours")

      conn =
        within(conn, "form[data-scope=reactions_sort]", fn c ->
          # Select "Amount of replies" from dropdown
          c = PhoenixTest.select(c, "Sort by", option: "Amount of replies")
          # Submit the form
          c
        end)

      # Check post with most replies is first
      conn = visit(conn, "/feed/local")
      assert_has(conn, "article", text: "alice post")
    end

    test "discussion default layout" do
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)

      # Create a post with replies
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      attrs = %{
        post_content: %{html_body: "reply 1"},
        reply_to_id: post.id
      }

      assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      conn = conn(user: alice, account: account)

      # Change thread layout to flat
      conn = visit(conn, "/settings/user/preferences/behaviours")

      conn =
        within(conn, "form[data-scope=set_thread_layout]", fn c ->
          # Select "Flat" from dropdown
          PhoenixTest.select(c, "Set thread layout", option: "Flat")
          # Submit the form
          # |> click_button("Save")
        end)

      # Check thread layout is flat
      conn = visit(conn, "/discussion/#{post.id}")
      assert_has(conn, "[data-role=comment-flat]")
    end

    test "discussion default sort" do
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)

      # Create a post with replies
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      attrs = %{
        post_content: %{html_body: "reply 1"},
        reply_to_id: post.id
      }

      assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      conn = conn(user: alice, account: account)

      # Change thread sorting to num_replies
      conn = visit(conn, "/settings/user/preferences/behaviours")

      conn =
        within(conn, "form[data-scope=set_thread_sorting]", fn c ->
          # Select "Number of replies" from dropdown
          c = PhoenixTest.select(c, "Sort by", option: "Amount of replies")
          # Submit the form
          # c = click_button(c, "Save")
          c
        end)

      # Check thread is sorted by replies
      conn = visit(conn, "/discussion/#{post.id}")
      assert_has(conn, "[data-sorted=num_replies]")
    end

    # test "show reaction counts (likes/boosts)" do
    #   Process.put(:feed_live_update_many_preload_mode, :inline)
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   bob = fake_user!(account)

    #   # Create a post with replies, likes and boosts
    #   attrs = %{
    #     post_content: %{html_body: "alice post"}
    #   }

    #   assert {:ok, post} =
    #            Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    #   attrs = %{
    #     post_content: %{html_body: "reply 2"},
    #     reply_to_id: post.id
    #   }

    #   assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

    #   # Add likes and boosts
    #   assert {:ok, like} = Likes.like(alice, p1)
    #   assert {:ok, like} = Likes.like(bob, p1)
    #   assert {:ok, boost} = Boosts.boost(alice, p1)
    #   assert {:ok, boost} = Boosts.boost(bob, p1)

    #   conn = conn(user: alice, account: account)

    #   # Show actions
    #   conn = visit(conn, "/settings/user/preferences/behaviours")

    #   conn =
    #     within(conn, "form[data-scope=set_hide_actions_on_feed]", fn c ->
    #       # Uncheck "Hide until hovered" checkbox
    #       c = uncheck(c, "Hide until hovered")
    #       # Submit the form
    #       c = click_button(c, "Save")
    #       c
    #     end)

    #   # Enable reaction counts
    #   conn =
    #     within(conn, "form[data-scope=set_show_reaction_counts]", fn c ->
    #       # Check "Show reaction counts" checkbox
    #       c = check(c, "Show reaction counts")
    #       # Submit the form
    #       c = click_button(c, "Save")
    #       c
    #     end)

    #   # Check reaction counts are visible
    #   conn = visit(conn, "/feed/local")
    #   assert_has(conn, "[data-role=reply_count]")
    # end
  end
end
