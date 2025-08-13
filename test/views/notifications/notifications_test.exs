defmodule Bonfire.UI.Social.Notifications.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows

  describe "show" do
    # test "with account" do
    #   account = fake_account!()
    #   conn = conn(account: account)
    #   next = "/notifications"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [_] = Floki.find(doc, "[data-id=feed]")
    # end

    @tag :skip_ci
    test "with user" do
      account = fake_account!()
      user = fake_user!(account)
      conn = conn(user: user, account: account)
      next = "/notifications"
      # |> IO.inspect
      {view, doc} = floki_live(conn, next)
      refute [] == Floki.find(doc, "[data-id=feed]")
    end
  end

  describe "DO NOT show" do
    test "when not logged in" do
      conn = conn()
      conn = get(conn, "/notifications")
      assert redirected_to(conn) =~ "/login"
    end

    # test "with account only" do
    #   account = fake_account!()
    #   conn = conn(account: account)
    #   next = "/notifications"
    #   {view, doc} = floki_live(conn, next) #|> IO.inspect
    #   assert [] == Floki.find(doc, "[data-id=feed]") # TODO: what to show in this case?
    # end
  end

  describe "PubSub real-time notifications" do
    setup do
      # Create users for testing
      alice = fake_user!("alice")
      bob = fake_user!("bob")
      charlie = fake_user!("charlie")

      # Create connections
      conn_alice = conn(user: alice, account: alice.account)
      conn_bob = conn(user: bob, account: bob.account)

      {:ok,
       %{
         alice: alice,
         bob: bob,
         charlie: charlie,
         conn_alice: conn_alice,
         conn_bob: conn_bob
       }}
    end

    test "receives real-time notification when mentioned in a post", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      mention_content = "check this out!"

      Posts.publish(
        current_user: bob,
        post_attrs: %{post_content: %{html_body: "Hey @alice " <> mention_content}},
        boundary: "public"
      )

      # Alice opens her notifications page
      conn = visit(conn_alice, "/notifications")

      mention_content_2 = "also check this other thing!"

      # Bob mentions Alice in a post (simulate from another session)
      Task.start(fn ->
        Posts.publish(
          current_user: bob,
          post_attrs: %{post_content: %{html_body: "Hey @alice " <> mention_content_2}},
          boundary: "public"
        )
      end)

      # Alice should see the mention notification appear in real-time
      conn
      |> assert_has_or_open_browser("[data-id=feed] article",
        text: mention_content_2,
        timeout: 3000
      )
      |> assert_has_or_open_browser("[data-role=subject]", text: bob.profile.name)
    end

    # NOTE: we don't actually notify unless there's an @ mention
    @tag :skip
    test "receives real-time notification when someone replies to user's post", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice creates a post first
      {:ok, original_post} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "Alice's original thinking"}},
          boundary: "public"
        )

      # Alice opens her notifications page
      conn = visit(conn_alice, "/notifications")

      reply_content = "Great point, Alice! I totally agree."

      # Bob replies to Alice's post (simulate from another session)
      Task.start(fn ->
        Posts.publish(
          current_user: bob,
          post_attrs: %{
            post_content: %{html_body: reply_content},
            reply_to_id: original_post.id
          },
          boundary: "public"
        )
      end)

      # Alice should see the reply notification appear in real-time
      conn
      |> assert_has_or_open_browser("[data-id=feed] article", text: reply_content, timeout: 3000)
      |> assert_has_or_open_browser("[data-role=subject]", text: bob.profile.name)
      |> assert_has_or_open_browser("[data-verb=Reply]")
    end

    @tag :skip_ci
    test "receives real-time notification when someone follows user", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice opens her notifications page
      conn = visit(conn_alice, "/notifications")

      # Bob follows Alice (simulate from another session)
      Task.start(fn ->
        Follows.follow(bob, alice)
      end)

      # Alice should see the follow notification appear in real-time
      conn
      |> assert_has_or_open_browser("[data-id=feed] article", timeout: 3000)
      |> assert_has_or_open_browser("[data-role=subject]", text: bob.profile.name)
      |> assert_has_or_open_browser("[data-verb=Follow]")
    end

    @tag :skip_ci
    test "receives real-time notification when someone likes user's post", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice creates a post first
      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "Something worth liking"}},
          boundary: "public"
        )

      # Alice opens her notifications page
      conn = visit(conn_alice, "/notifications")

      # Bob likes Alice's post (simulate from another session)
      Task.start(fn ->
        alias Bonfire.Social.Likes
        Likes.like(bob, post)
      end)

      # Alice should see the like notification appear in real-time
      conn
      |> assert_has_or_open_browser("[data-verb=Like]", timeout: 3000)
      |> assert_has_or_open_browser("[data-id=feed] article", timeout: 3000)
      |> assert_has_or_open_browser("[data-role=subject]", text: bob.profile.name)
    end

    @tag :skip_ci
    test "receives real-time notification when someone boosts user's post", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice creates a post first
      {:ok, post} =
        Posts.publish(
          current_user: alice,
          post_attrs: %{post_content: %{html_body: "Something worth boosting"}},
          boundary: "public"
        )

      # Alice opens her notifications page
      conn = visit(conn_alice, "/notifications")

      # Bob boosts Alice's post (simulate from another session)
      Task.start(fn ->
        alias Bonfire.Social.Boosts
        Boosts.boost(bob, post)
      end)

      # Alice should see the boost notification appear in real-time
      conn
      |> assert_has_or_open_browser("[data-id=feed] article", timeout: 3000)
      |> assert_has_or_open_browser("[data-role=subject]", text: bob.profile.name)
      |> assert_has_or_open_browser("[data-verb=Boost]")
    end

    @tag :todo
    test "notification count badge updates in real-time", %{
      alice: alice,
      bob: bob,
      conn_alice: conn_alice
    } do
      # Alice opens any page (not notifications)
      conn = visit(conn_alice, "/feed")

      # Bob mentions Alice
      Task.start(fn ->
        Posts.publish(
          current_user: bob,
          post_attrs: %{post_content: %{html_body: "Hey @alice!"}},
          boundary: "public"
        )
      end)

      # TODO: Check that the notification badge/counter updates in real-time
      # This tests the counter increment PubSub message
      # conn
      # |> assert_has_or_open_browser("[data-role=notifications_nav]", timeout: 3000)
    end
  end
end
