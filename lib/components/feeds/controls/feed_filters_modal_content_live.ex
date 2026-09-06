defmodule Bonfire.UI.Social.FeedFiltersModalContentLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
  prop context_key, :any, default: nil
  prop apply_to, :any, default: :parent

  data pending_filters, :map, default: nil
  data init_state, :any, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    filters = Enums.maybe_to_map(socket.assigns.feed_filters) || %{}
    state = {filters, socket.assigns.context_key}

    socket =
      if socket.assigns[:init_state] == state do
        socket
      else
        context = socket.assigns[:__context__]
        my_circles =
          if context do
            Bonfire.UI.Boundaries.SetBoundariesLive.circles_for_multiselect(context, :subject_circles) || []
          else
            []
          end

        assign(socket, init_state: state, pending_filters: filters, my_circles: my_circles)
      end

    {:ok, assign_derived(socket)}
  end

  # Apply reads pending state rather than a phx-value snapshot from the last render.
  def handle_event("apply", _params, socket) do
    assigns = assigns(socket)
    {applied, _context} = assigns[:init_state]
    pending = assigns[:pending_filters]

    filters = filters_to_apply(pending, applied)

    case assigns[:apply_to] do
      {module, host_id} ->
        Phoenix.LiveView.send_update(module, id: host_id, apply_filters: filters)

      %Phoenix.LiveComponent.CID{} = cid ->
        Phoenix.LiveView.send_update(cid, apply_filters: filters)

      :parent ->
        send(self(), {__MODULE__, :apply, filters})
    end

    {:noreply, socket}
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

  # NB: also drives the "Hide my own activities" checkbox (toggle=subjects with the current
  # user's id as toggle_type), so there's a single write path for include/exclude lists
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
           |> Map.put(exclude_field, Enum.reject(already_excluded, &same_type?(&1, type_atom)))

         "false" ->
           filters
           |> Map.put(include_field, Enum.reject(already_selected, &same_type?(&1, type_atom)))
           |> Map.put(exclude_field, Enum.uniq(already_excluded ++ [type_atom]))

         _ ->
           filters
           |> Map.put(include_field, Enum.reject(already_selected, &same_type?(&1, type_atom)))
           |> Map.put(exclude_field, Enum.reject(already_excluded, &same_type?(&1, type_atom)))
       end
     end)}
  end

  # list entries may be atoms, strings, ids, or loaded objects (e.g. exclude_subjects can
  # hold user structs from a saved feed) — compare their normalized string forms
  defp same_type?(entry, type) do
    to_string(Enums.id(entry) || entry) == to_string(Enums.id(type) || type)
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

  @doc """
  Includes explicit removals because feed hosts merge partial updates. Scalar resets use the same values as the editor's All time and default-order controls.

      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.filters_to_apply(%{}, %{time_limit: 1, sort_by: :like_count, sort_order: :asc, subjects: ["alice"], origin: :remote})
      %{time_limit: 0, sort_by: false, sort_order: :desc, subjects: [], origin: :all}
      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.filters_to_apply(%{time_limit: 30}, %{time_limit: 1})
      %{time_limit: 30}
  """
  def filters_to_apply(pending, applied) do
    (Map.keys(applied) -- Map.keys(pending))
    |> Enum.reduce(pending, fn
      :origin, acc -> Map.put(acc, :origin, :all)
      :time_limit, acc -> Map.put(acc, :time_limit, 0)
      :sort_by, acc -> Map.put(acc, :sort_by, false)
      :sort_order, acc -> Map.put(acc, :sort_order, :desc)
      key, acc -> if is_list(applied[key]), do: Map.put(acc, key, []), else: acc
    end)
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
