defmodule Bonfire.UI.Social.FeedFiltersModalContentLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil

  def update(assigns, socket) do
    # Don't overwrite pending changes on subsequent updates
    socket =
      if socket.assigns[:pending_filters] do
        socket |> assign(assigns)
      else
        filters = Enums.maybe_to_map(assigns[:feed_filters]) || %{}
        context = assigns[:__context__] || socket.assigns[:__context__]

        my_circles =
          if context do
            Bonfire.UI.Boundaries.SetBoundariesLive.circles_for_multiselect(
              context,
              :subject_circles
            ) || []
          else
            []
          end

        socket
        |> assign(assigns)
        |> assign(pending_filters: filters, my_circles: my_circles)
      end

    {:ok, socket}
  end

  def handle_event("set_filter", %{"time_limit" => time_limit} = _attrs, socket) do
    {:noreply, update_pending(socket, :time_limit, Types.maybe_to_integer(time_limit))}
  end

  def handle_event("set_filter", %{"sort_order" => sort_order}, socket) do
    {:noreply, update_pending(socket, :sort_order, maybe_to_atom(sort_order))}
  end

  def handle_event("set_filter", %{"origin" => "all"}, socket) do
    {:noreply, update_pending_fn(socket, &Map.delete(&1, :origin))}
  end

  def handle_event("set_filter", %{"origin" => origin}, socket) do
    {:noreply, update_pending(socket, :origin, maybe_to_atom(origin))}
  end

  def handle_event(
        "set_filter",
        %{"toggle" => field, "toggle_type" => type} = params,
        socket
      ) do
    include_field = maybe_to_atom(field)
    exclude_field = maybe_to_atom("exclude_#{field}")
    type_atom = Types.maybe_to_atom(type)
    value = params["toggle_value"]

    {:noreply,
     update_pending_fn(socket, fn filters ->
       already_selected = List.wrap(e(filters, include_field, []))
       already_excluded = List.wrap(e(filters, exclude_field, []))

       case value do
         "true" ->
           filters
           |> Map.put(include_field, Enum.uniq(already_selected ++ [type_atom]))
           |> Map.put(exclude_field, Enum.reject(already_excluded, &(&1 == type_atom)))

         "false" ->
           filters
           |> Map.put(include_field, Enum.reject(already_selected, &(&1 == type_atom)))
           |> Map.put(exclude_field, Enum.uniq(already_excluded ++ [type_atom]))

         _ ->
           filters
           |> Map.put(include_field, Enum.reject(already_selected, &(&1 == type_atom)))
           |> Map.put(exclude_field, Enum.reject(already_excluded, &(&1 == type_atom)))
       end
     end)}
  end

  def handle_event("set_filter", %{"subject_circles" => circle_id}, socket) do
    {:noreply,
     update_pending_fn(socket, fn filters ->
       current = e(filters, :subject_circles, [])

       updated =
         if circle_id in current,
           do: List.delete(current, circle_id),
           else: [circle_id | current]

       Map.put(filters, :subject_circles, Enum.uniq(updated))
     end)}
  end

  def handle_event("set_filter", attrs, socket) do
    {:noreply,
     update_pending_fn(socket, fn filters ->
       Enums.merge_as_map(filters, Enums.naughty_to_atoms!(attrs))
     end)}
  end

  @doc "Encodes filters map to JSON for passing via phx-value."
  def encode_filters(filters) do
    filters
    |> Enums.nested_structs_to_maps()
    |> Jason.encode!()
  end

  defp update_pending(socket, key, value) do
    pending = socket.assigns[:pending_filters] || %{}
    assign(socket, :pending_filters, Map.put(pending, key, value))
  end

  defp update_pending_fn(socket, fun) do
    pending = socket.assigns[:pending_filters] || %{}
    assign(socket, :pending_filters, fun.(pending))
  end
end
