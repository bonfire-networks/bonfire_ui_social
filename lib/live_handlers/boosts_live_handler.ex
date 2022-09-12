defmodule Bonfire.Social.Boosts.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  # boost in LV stateful component
  def handle_event("boost", params, %{assigns: %{object: object}} = socket) do
    do_boost(object, params, socket)
  end

  # boost in LV
  def handle_event("boost", %{"id" => id} = params, socket) do
    do_boost(id, params, socket)
  end

  # unboost in LV
  def handle_event("undo", %{"id" => id} = params, socket) do
    with {:ok, unboost} <- Bonfire.Social.Boosts.unboost(current_user(socket), id) do
      boost_action(id, false, params, socket)
    end
  end

  # boost in LV
  def do_boost(object, params, socket) do
    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("boost"), object),
         {:ok, boost} <- Bonfire.Social.Boosts.boost(current_user, object) do
      boost_action(object, true, params, socket)
    end
  end

  defp boost_action(object, boost?, params, socket) do
    ComponentID.send_updates(
      Bonfire.UI.Common.BoostActionLive,
      ulid(object),
      my_boost: boost?
    )

    {:noreply, socket}
  end

  def preload(list_of_assigns) do
    current_user = current_user(List.first(list_of_assigns))
    # |> debug("current_user")

    list_of_objects =
      list_of_assigns
      |> Enum.map(&e(&1, :object, nil))

    # |> debug("list_of_objects")

    list_of_ids =
      list_of_objects
      |> Enum.map(&e(&1, :id, nil))
      |> filter_empty([])
      |> debug("list_of_ids")

    my_states =
      if current_user,
        do:
          Bonfire.Social.Boosts.get!(current_user, list_of_ids, preload: false)
          |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end),
        else: %{}

    debug(my_states, "my_boosts")

    objects_counts =
      if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: current_user) do
        list_of_objects
        |> repo().maybe_preload(:boost_count, follow_pointers: false)
        |> Map.new(fn o -> {e(o, :id, nil), e(o, :boost_count, :object_count, nil)} end)
        |> debug("boost_counts")
      end

    list_of_assigns
    |> Enum.map(fn assigns ->
      object_id = e(assigns, :object, :id, nil)

      assigns
      |> Map.put(
        :my_boost,
        e(my_states, object_id, nil)
      )
      |> Map.put(
        :boost_count,
        e(objects_counts, object_id, nil)
      )
    end)
  end
end
