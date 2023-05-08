defmodule Bonfire.Social.Follows.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  alias Bonfire.Boundaries.Circles



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

  def handle_event("accept", %{"id" => id} = _params, socket) do
    # debug(socket)

    with {:ok, _follow} <-
           Bonfire.Social.Follows.accept(id, current_user: current_user_required!(socket)) do
      {:noreply, socket}
    else
      e ->
        error(e, l("There was an error when trying to accept the request"))
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
      object_id: e(assigns, :object_id, nil) || ulid(object),
      previous_value: e(assigns, :my_follow, nil)
    }
  end

  defp do_preload(list_of_components, list_of_ids, current_user) do

    # # Here we're checking if the user is ghosted / silenced by user or instance
    # ghosted? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :ghost, current_user: current_user) |> debug("ghosted?")
    # ghosted_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :ghost, :instance_wide) |> debug("ghosted_instance_wide?")
    # silenced? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :silence, current_user: current_user) |> debug("silenced?")
    # silenced_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :silence, :instance_wide) |> debug("silenced_instance_wide?")

    my_follows =
      if current_user,
        do:
          Bonfire.Social.Follows.get!(current_user, list_of_ids,
            preload: false,
            skip_boundary_check: true
          )
          |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end),
        else: %{}

    debug(my_follows, "my_follows")

    followed_ids = Map.keys(my_follows)

    remaining_ids =
      Enum.reject(list_of_ids, &(&1 in followed_ids))
      |> debug("remaining_ids")

    my_requests =
      if current_user,
        do:
          Bonfire.Social.Requests.get!(current_user, Bonfire.Data.Social.Follow, remaining_ids,
            preload: false,
            skip_boundary_check: true
          )
          |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end),
        else: %{}

    debug(my_requests, "my_requests")

    list_of_components
    |> Map.new(fn component ->
      {component.component_id,
       %{
         my_follow:
           if(Map.get(my_requests, component.object_id), do: :requested) ||
             Map.get(my_follows, component.object_id) || component.previous_value || false,
          # ghosted?: ghosted?,
          # ghosted_instance_wide?: ghosted_instance_wide?,
          # silenced?: silenced?,
          # silenced_instance_wide?: silenced_instance_wide?
       }}
    end)
  end
end
