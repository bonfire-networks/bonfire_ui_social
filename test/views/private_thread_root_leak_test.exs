defmodule Bonfire.UI.Social.PrivateThreadRootLeakTest do
  @moduledoc """
  A viewer who can read a reply but not the private post it answers must not get that post's id from the page, for instance through the reply's thread link.
  """
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.Posts

  @moduletag :ui

  test "a reply's page doesn't carry the id of a private thread root the viewer can't read" do
    Process.put([:bonfire, :default_pagination_limit], 10)

    author = fake_user!("private_root_author")
    viewer = fake_user!("private_root_viewer")

    {:ok, root} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "A private root"}},
        boundary: "mentions"
      )

    {:ok, reply} =
      Posts.publish(
        current_user: author,
        post_attrs: %{post_content: %{html_body: "A public reply"}, reply_to_id: root.id},
        boundary: "public"
      )

    assert {:error, _} = Posts.read(root.id, current_user: viewer)
    assert {:ok, _} = Posts.read(reply.id, current_user: viewer)

    conn(user: viewer, account: viewer.account)
    |> visit("/feed/local")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "A public reply")
    |> PhoenixTest.unwrap(fn view ->
      html = Phoenix.LiveViewTest.render(view)

      refute html =~ root.id,
             "the private thread root's id is in the rendered feed"

      html
    end)
  end

  # a feed row shows no thread title, and the root itself (its id and link) stays out of reach
  describe "the title of a private thread root the viewer can't read" do
    @title "Secret thread title zq81"

    setup do
      Process.put([:bonfire, :default_pagination_limit], 10)

      author = fake_user!("private_title_author")
      viewer = fake_user!("private_title_viewer")

      {:ok, root} =
        Posts.publish(
          current_user: author,
          post_attrs: %{name: @title, post_content: %{html_body: "A private titled root"}},
          boundary: "mentions"
        )

      {:ok, reply} =
        Posts.publish(
          current_user: author,
          post_attrs: %{
            post_content: %{html_body: "A public titled-thread reply"},
            reply_to_id: root.id
          },
          boundary: "public"
        )

      # the title really is on the root, and the viewer really can't read the root but can read the reply
      assert Bonfire.Common.Repo.preload(root, :named, force: true).named.name == @title
      refute Bonfire.Boundaries.can?(viewer, :read, root)
      assert Bonfire.Boundaries.can?(viewer, :read, reply)

      {:ok, author: author, viewer: viewer, root: root, reply: reply}
    end

    # the page as first sent (head included), following the redirect from a reply's own address to its place in the thread
    defp page_html(viewer, path) do
      follow(viewer, path, 4)
    end

    defp follow(viewer, path, hops_left) do
      conn = get(conn(user: viewer, account: viewer.account), path)

      if conn.status == 302 and hops_left > 0 do
        follow(viewer, Phoenix.ConnTest.redirected_to(conn), hops_left - 1)
      else
        html_response(conn, 200)
      end
    end

    test "control: is in the feed row of a reply when the viewer can read the root", %{
      author: author,
      viewer: viewer
    } do
      {:ok, root} =
        Posts.publish(
          current_user: author,
          post_attrs: %{
            name: "Open thread title qw55",
            post_content: %{html_body: "An open root"}
          },
          boundary: "public"
        )

      {:ok, reply} =
        Posts.publish(
          current_user: author,
          post_attrs: %{post_content: %{html_body: "An open reply"}, reply_to_id: root.id},
          boundary: "public"
        )

      assert Bonfire.Boundaries.can?(viewer, :read, root)

      conn(user: viewer, account: viewer.account)
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "An open reply")
      |> PhoenixTest.unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)
        assert html =~ "Open thread title qw55"
        html
      end)
    end

    # a reply's own page has no place for the thread's title, so there is nothing to show or hide there: it still shows the reply
    test "doesn't stop the reply's own page from showing", %{viewer: viewer, reply: reply} do
      html = page_html(viewer, "/post/#{reply.id}")
      assert html =~ "A public titled-thread reply"

      conn(user: viewer, account: viewer.account)
      |> visit("/post/#{reply.id}")
      |> wait_async()
      |> assert_has("main", text: "A public titled-thread reply")
    end

    test "doesn't stop the reply's discussion page from showing", %{viewer: viewer, reply: reply} do
      html = page_html(viewer, "/discussion/#{reply.id}")
      assert html =~ "A public titled-thread reply"

      conn(user: viewer, account: viewer.account)
      |> visit("/discussion/#{reply.id}")
      |> wait_async()
      |> assert_has("main", text: "A public titled-thread reply")
    end

    test "doesn't bring the root's id to the feed showing the reply", %{
      viewer: viewer,
      root: root
    } do
      conn(user: viewer, account: viewer.account)
      |> visit("/feed/local")
      |> wait_async()
      |> assert_has("[data-id=feed]", text: "A public titled-thread reply")
      |> PhoenixTest.unwrap(fn view ->
        html = Phoenix.LiveViewTest.render(view)
        refute html =~ root.id, "the private thread root's id is in the feed"
        html
      end)
    end
  end
end
