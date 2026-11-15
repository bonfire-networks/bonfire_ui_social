defmodule Bonfire.UI.Social.ReplyThreadChildrenTest do
  @moduledoc """
  Opening a reply, by its own page or from a feed's preview, lists the replies to it, whether or not the viewer can read the thread's root.
  """
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Posts

  defp publish!(user, body, boundary, reply_to_id \\ nil) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}, reply_to_id: reply_to_id},
        boundary: boundary
      )

    post
  end

  # root R -> reply A -> reply B (to A)
  defp thread!(author, root_boundary) do
    root = publish!(author, "the thread root zr1", root_boundary)
    a = publish!(author, "the first reply zr2", "public", root.id)
    b = publish!(author, "the reply to the reply zr3", "public", a.id)
    {root, a, b}
  end

  defp open_preview(view, post) do
    view
    |> with_target(~s([id$="open_preview_#{id(post)}"]))
    |> render_hook("open", %{"previous_url" => "/feed/local", "previous_scroll" => 0})

    render(view)
  end

  setup do
    Process.put([:bonfire, :default_pagination_limit], 10)
    author = fake_user!(fake_account!())
    viewer = fake_user!(fake_account!())
    {:ok, author: author, viewer: viewer, conn: conn(user: viewer, account: viewer.account)}
  end

  for {label, root_boundary} <- [{"readable", "public"}, {"unreadable", "mentions"}] do
    describe "when the viewer's #{label} root" do
      @describetag root_boundary: root_boundary

      setup %{author: author, viewer: viewer, root_boundary: root_boundary} do
        {root, a, b} = thread!(author, root_boundary)

        if root_boundary == "public",
          do: assert({:ok, _} = Posts.read(root.id, current_user: viewer)),
          else: assert({:error, _} = Posts.read(root.id, current_user: viewer))

        assert {:ok, _} = Posts.read(a.id, current_user: viewer)
        assert {:ok, _} = Posts.read(b.id, current_user: viewer)
        {:ok, root: root, a: a, b: b}
      end

      test "the reply's /post page lists the reply to it", %{conn: conn, a: a} do
        conn
        |> visit("/post/#{a.id}")
        |> wait_async()
        |> assert_has("main", text: "the first reply zr2")
        |> assert_has("main", text: "the reply to the reply zr3")
      end

      test "the reply's /discussion page lists the reply to it", %{conn: conn, a: a} do
        conn
        |> visit("/discussion/#{a.id}")
        |> wait_async()
        |> assert_has("main", text: "the first reply zr2")
        |> assert_has("main", text: "the reply to the reply zr3")
      end

      # a feed's preview of a reply names the thread root in its trigger's id when the root is readable (and then also shows the root), so only the unreadable-root case can be driven by the reply's own id
      if root_boundary == "mentions" do
        test "the reply's preview from a feed lists the reply to it", %{conn: conn, a: a} do
          {:ok, view, _html} = live(conn, "/feed/local")
          open_preview(view, a)

          html =
            view
            |> render_async()
            |> then(fn _ -> view |> element("#preview_content") |> render() end)

          assert html =~ "the first reply zr2"
          assert html =~ "the reply to the reply zr3"
        end
      end
    end
  end
end
