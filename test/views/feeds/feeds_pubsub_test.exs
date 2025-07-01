defmodule Bonfire.UI.Social.Feeds.PubSub.Test do
  use Bonfire.UI.Social.ConnCase, async: true
  @moduletag :ui
  alias Bonfire.Social.Fake
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  setup do
    me = fake_user!("meee")
    alice = fake_user!("alice")

    conn = conn(user: me)

    {:ok, conn: conn, alice: alice, me: me}
  end

  test "new post appears in the local feed in real time", %{conn: conn, alice: alice} do
    # Open the local feed as a user
    conn = visit(conn, "/feed/local")

    # The content for the new post
    new_post_content = "This is a live post in the local feed"

    # Post as another user in a separate process (simulate another tab/session)
    Task.start(fn ->
      # :timer.sleep(500) # Give the feed time to subscribe?
      Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: new_post_content}},
        boundary: "public"
      )
    end)

    # Wait for the new post to appear via PubSub
    conn
    |> assert_has_or_open_browser("[data-id=object_body]", text: new_post_content, timeout: 3000)
  end

  test "new post appears in a profile feed in real time", %{
    conn: conn,
    alice: alice
  } do
    # Open Alice's profile feed as myself
    conn = visit(conn, "/user/#{alice.id}")

    new_post_content = "This is a live post from alice"

    # Post as Alice in a separate process
    Task.start(fn ->
      Bonfire.Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: new_post_content}},
        boundary: "public"
      )
    end)

    conn
    |> assert_has_or_open_browser("[data-id=object_body]", text: new_post_content, timeout: 3000)
  end

  test "new reply appears in a thread feed in real time", %{conn: conn, alice: alice} do
    # Alice creates a thread
    {:ok, %{id: thread_id} = post} =
      Bonfire.Posts.publish(
        current_user: alice,
        post_attrs: %{post_content: %{html_body: "Thread root"}},
        boundary: "public"
      )

    # Visit the thread page as Alice (adjust path as needed)
    conn = visit(conn, "/post/#{thread_id}")

    reply_content = "This is a live reply in the thread"

    # Post a reply as Alice in a separate process
    Task.start(fn ->
      Bonfire.Posts.publish(
        current_user: alice,
        post_attrs: %{
          post_content: %{html_body: reply_content},
          reply_to: thread_id
        },
        boundary: "public"
      )
    end)

    conn
    |> assert_has_or_open_browser("[data-id=object_body]", text: reply_content, timeout: 3000)
  end

  test "new message I receive appears in my inbox in real time", %{
    conn: conn,
    me: me,
    alice: alice
  } do
    # Visit inbox as me
    conn = visit(conn, "/messages")

    message_content = "This is a live message from alice"

    # Send a message as Alice in a separate process
    Task.start(fn ->
      Bonfire.Messages.send(
        alice,
        %{post_content: %{html_body: message_content}},
        [me.id]
      )
    end)

    conn
    |> assert_has_or_open_browser("#message_threads", text: message_content, timeout: 3000)
  end

  test "new message I send appears in my own inbox in real time", %{
    conn: conn,
    me: me,
    alice: alice
  } do
    # Visit inbox as me
    conn = visit(conn, "/messages")

    message_content = "This is a live message from alice"

    # Send a message by me in a separate process
    Task.start(fn ->
      Bonfire.Messages.send(
        me,
        %{post_content: %{html_body: message_content}},
        [alice.id]
      )
    end)

    conn
    |> assert_has_or_open_browser("#message_threads", text: message_content, timeout: 3000)
  end
end
