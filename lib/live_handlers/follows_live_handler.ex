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
    with _ <- Bonfire.Social.Follows.unfollow(current_user_required(socket), id) do
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
           Bonfire.Social.Follows.accept(id, current_user: current_user_required(socket)) do
      {:noreply, socket}
    else
      e ->
        debug(e)
        {:error, "Could not unfollow"}
    end
  end

  def preload(list_of_assigns) do
    current_user = current_user(List.first(list_of_assigns))
    # |> debug("current_user")

    list_of_objects =
      list_of_assigns
      |> Enum.map(&e(&1, :object, nil))

    # |> repo().maybe_preload(:like_count)
    # |> debug("list_of_objects")

    list_of_ids =
      list_of_objects
      |> Enum.map(&e(&1, :id, nil))
      |> filter_empty([])

    # |> debug("list_of_ids")

    my_states =
      if current_user,
        do:
          Bonfire.Social.Follows.get!(current_user, list_of_ids,
            preload: false,
            skip_boundary_check: true
          )
          |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end),
        else: %{}

    # debug(my_states, "my_follows")

    # objects_counts = list_of_objects |> Map.new(fn o -> {e(o, :id, nil), e(o, :like_count, :object_count, nil)} end)
    # |> debug("follow_counts")

    list_of_assigns
    |> Enum.map(fn assigns ->
      object_id = e(assigns, :object, :id, nil)
      # debug(object_id, "object_id")
      value =
        if current_user,
          do: Map.get(my_states, object_id),
          else: Map.get(List.first(list_of_assigns), :my_follow)

      assigns
      |> Map.put(
        :my_follow,
        value
      )

      # |> Map.put(
      #   :like_count,
      #   Map.get(objects_counts, object_id)
      # )
    end)
  end
end
