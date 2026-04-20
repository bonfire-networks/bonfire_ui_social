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
        socket |> assign(assigns) |> assign_derived()
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
        |> assign_derived()
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

  def handle_event("reset_pending", _params, socket) do
    {:noreply, assign(socket, :pending_filters, %{})}
  end

  def handle_event("remove_active_filter", %{"field" => field, "key" => key}, socket) do
    field_atom = maybe_to_atom(field)

    {:noreply,
     update_pending_fn(socket, fn filters ->
       case Map.get(filters, field_atom) do
         list when is_list(list) ->
           remaining = Enum.reject(list, fn v -> to_string(v) == key end)

           if remaining == [],
             do: Map.delete(filters, field_atom),
             else: Map.put(filters, field_atom, remaining)

         _ ->
           Map.delete(filters, field_atom)
       end
     end)}
  end

  def handle_event("remove_active_filter", %{"field" => field}, socket) do
    field_atom = maybe_to_atom(field)
    {:noreply, update_pending_fn(socket, &Map.delete(&1, field_atom))}
  end

  @doc "True when the current :origin filter matches the given option (`:all`, `:local`, `:remote`)."
  def origin_matches?(filters, :all), do: e(filters, :origin, nil) in [nil, :all]
  def origin_matches?(filters, origin), do: e(filters, :origin, nil) in [origin, [origin]]

  @doc "Encodes filters map to JSON for passing via phx-value."
  def encode_filters(filters) do
    filters
    |> Enums.nested_structs_to_maps()
    |> Jason.encode!()
  end

  @doc "Human-readable summary shown in the collapsed Time range section header."
  def time_range_summary(filters) do
    case e(filters, :time_limit, nil) do
      days when days in [nil, 0] ->
        l("All time")

      days ->
        Enum.find_value(
          Bonfire.UI.Social.TimeControlLive.default_options(),
          fn {v, name} -> if v == days, do: name end
        ) || "#{days}d"
    end
  end

  @doc "Human-readable summary shown in the collapsed Sort order section header."
  def sort_order_summary(filters) do
    case e(filters, :sort_order, nil) do
      :asc -> l("Oldest first")
      _ -> l("Newest first")
    end
  end

  @doc "Short summary for a type field, e.g. 'All', '2 only', '1 hidden', '2 only · 1 hidden'."
  def types_summary(filters, field) do
    include = length(List.wrap(e(filters, field, [])))
    exclude = length(List.wrap(e(filters, maybe_to_atom("exclude_#{field}"), [])))

    case {include, exclude} do
      {0, 0} -> l("All")
      {n, 0} -> l("%{count} only", count: n)
      {0, n} -> l("%{count} hidden", count: n)
      {a, b} -> l("%{a} only · %{b} hidden", a: a, b: b)
    end
  end

  @doc "Short summary for the circles section: 'None' or 'N selected'."
  def circles_summary(filters) do
    case List.wrap(e(filters, :subject_circles, [])) do
      [] -> l("None")
      list -> l("%{count} selected", count: length(list))
    end
  end

  defp update_pending(socket, key, value) do
    pending = socket.assigns[:pending_filters] || %{}
    socket |> assign(:pending_filters, Map.put(pending, key, value)) |> assign_derived()
  end

  defp update_pending_fn(socket, fun) do
    pending = socket.assigns[:pending_filters] || %{}
    socket |> assign(:pending_filters, fun.(pending)) |> assign_derived()
  end

  defp assign_derived(socket) do
    filters = socket.assigns[:pending_filters] || %{}
    context = socket.assigns[:__context__]

    assign(socket,
      active_filters: Bonfire.UI.Social.FeedControlsLive.active_filters(filters, context),
      user_activities_excluded?:
        Bonfire.UI.Social.FeedExtraControlsLive.user_activities_excluded?(filters, context),
      replies_excluded?: Bonfire.UI.Social.FeedExtraControlsLive.replies_excluded?(filters),
      boosts_excluded?: Bonfire.UI.Social.FeedExtraControlsLive.boosts_excluded?(filters),
      preset_origin_info:
        Bonfire.UI.Social.FeedExtraControlsLive.get_preset_origin_info(filters, context)
    )
  end
end
