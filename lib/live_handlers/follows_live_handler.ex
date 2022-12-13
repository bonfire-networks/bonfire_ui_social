defmodule Bonfire.Social.Follows.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  def handle_event("follow", %{"id" => id} = params, socket) do
    # debug(socket)

    set = [
      my_follow: true
    ]

    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("follow"), id),
         {:ok, _follow} <- Bonfire.Social.Follows.follow(current_user, id) do
      ComponentID.send_assigns(
        e(params, "component", Bonfire.UI.Common.FollowButtonLive),
        id,
        set,
        socket
      )
    else
      e ->
        debug(e)
        {:error, "Could not follow"}
    end
  end

  def handle_event("unfollow", %{"id" => id} = params, socket) do
    with _ <- Bonfire.Social.Follows.unfollow(current_user_required!(socket), id) do
      set = [
        my_follow: false
      ]

      ComponentID.send_assigns(
        e(params, "component", Bonfire.UI.Common.FollowButtonLive),
        id,
        set,
        socket
      )

      # TODO: handle errors
    end
  end

  def handle_event("accept", %{"id" => id} = params, socket) do
    # debug(socket)

    with {:ok, _follow} <-
           Bonfire.Social.Follows.accept(id, current_user: current_user_required!(socket)) do
      {:noreply, socket}
    else
      e ->
        debug(e)
        {:error, "Could not unfollow"}
    end
  end

  def preload(list_of_assigns, opts \\ []) do
    preload_assigns_async(list_of_assigns, &assigns_to_params/1, &do_preload/3, opts)
  end

  defp assigns_to_params(assigns) do
    object = e(assigns, :object, nil)

    %{
      component_id: assigns.id,
      object: object,
      object_id: ulid(object),
      previous_value: e(assigns, :my_follow, nil)
    }
  end

  defp do_preload(list_of_components, list_of_ids, current_user) do
    my_states =
      if current_user,
        do:
          Bonfire.Social.Follows.get!(current_user, list_of_ids,
            preload: false,
            skip_boundary_check: true
          )
          |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end),
        else: %{}

    debug(my_states, "my_follows")

    list_of_components
    |> Map.new(fn component ->
      {component.component_id,
       %{
         my_follow: Map.get(my_states, component.object_id) || component.previous_value || false
       }}
    end)
  end
end
