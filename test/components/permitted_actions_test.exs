defmodule Bonfire.UI.Social.PermittedActionsTest do
  @moduledoc """
  An activity's "More actions" menu works out what the viewer may do with the post when it's opened: its trigger pushes `load` to `PermittedActionsLive`. The handler is called directly, since a feed row's re-renders never reach the LiveViewTest DOM.
  """
  use Bonfire.UI.Social.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts
  alias Bonfire.UI.Social.Activity.MoreActionsLive
  alias Bonfire.UI.Social.Activity.PermittedActionsLive

  @post %{object: %{id: "01OBJ"}, object_type: Bonfire.Data.Social.Post}
  @message %{object: %{id: "01MSG"}, object_type: Bonfire.Data.Social.Message}

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, account: account, me: me}
  end

  defp with_viewer(assigns, user), do: Map.put(assigns, :__context__, %{current_user: user})

  describe "opening the menu" do
    test "pushes nothing for a guest, so a cached page without LiveView doesn't navigate away" do
      refute MoreActionsLive.permitted_actions?(with_viewer(@post, nil))
      assert MoreActionsLive.load_on_open(with_viewer(@post, nil)).ops == []
    end

    test "loads a signed-in user's permission rows", %{me: me} do
      assigns = with_viewer(@post, me)
      target = "#" <> MoreActionsLive.lazy_id(assigns, "permitted_actions")

      assert MoreActionsLive.permitted_actions?(assigns)
      assert ["push", %{event: "load", target: target}] in MoreActionsLive.load_on_open(assigns).ops
    end

    test "loads no permission rows on a direct message", %{me: me} do
      assigns = with_viewer(@message, me)
      target = "#" <> MoreActionsLive.lazy_id(assigns, "permitted_actions")

      refute MoreActionsLive.permitted_actions?(assigns)
      refute ["push", %{event: "load", target: target}] in MoreActionsLive.load_on_open(assigns).ops
    end
  end

  describe "the load handler" do
    defp socket(me, assigns),
      do: %Phoenix.LiveView.Socket{
        assigns:
          Map.merge(
            %{
              __changed__: %{},
              flash: %{},
              current_user: me,
              __context__: %{current_user: me},
              permitted: nil,
              creator: nil,
              published_in: nil
            },
            assigns
          )
      }

    defp publish!(me, body) do
      {:ok, post} =
        Posts.publish(
          current_user: me,
          post_attrs: %{post_content: %{html_body: body}},
          boundary: "public"
        )

      post
    end

    test "fetches the boundary on the first open only", %{me: me} do
      post = publish!(me, "once")
      test_pid = self()

      Repatch.patch(Bonfire.Boundaries, :boundaries_on_objects, fn ids, user ->
        send(test_pid, {:fetched, ids})
        Repatch.real(Bonfire.Boundaries, :boundaries_on_objects, [ids, user])
      end)

      {:noreply, socket} =
        PermittedActionsLive.handle_event("load", %{}, socket(me, %{object: post}))

      post_id = id(post)
      assert_received {:fetched, [^post_id]}
      assert is_map(socket.assigns.boundary)
      assert %{edit: true, delete: true, remove_from_group: false} = socket.assigns.permitted

      {:noreply, _} = PermittedActionsLive.handle_event("load", %{}, socket)
      refute_received {:fetched, _}
    end

    test "a stranger may neither edit nor delete", %{me: me} do
      post = publish!(fake_user!(fake_account!()), "theirs")

      {:noreply, socket} =
        PermittedActionsLive.handle_event("load", %{}, socket(me, %{object: post}))

      # the control: a boundary was fetched, so the refusals below come from it
      assert is_map(socket.assigns.boundary)
      assert %{edit: false, delete: false, remove_from_group: false} = socket.assigns.permitted
    end
  end
end
