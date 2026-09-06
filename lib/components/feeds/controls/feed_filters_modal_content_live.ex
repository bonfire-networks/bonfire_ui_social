defmodule Bonfire.UI.Social.FeedFiltersModalContentLive do
  @moduledoc """
  Shared filter editor for feeds and search. Rows expand inline to edit their values; changes stay pending until Apply in both contexts.

  Hosts supply available rows, type options, draft identity and an explicit Apply recipient. Component recipients receive `apply_filters` through `send_update`; the parent LiveView receives `{__MODULE__, :apply, filters}`.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Social.FeedFilters

  @filter_fields [
    origin: [:origin],
    hide_own: [:exclude_subjects],
    from_people: [:subjects],
    not_people: [:exclude_subjects],
    hashtags: [:tags],
    time_range: [:time_limit],
    sort_order: [:sort_by, :sort_order],
    object_types: [:object_types, :exclude_object_types],
    activity_types: [:activity_types, :exclude_activity_types],
    media_types: [:media_types, :exclude_media_types],
    subject_types: [:subject_types, :exclude_subject_types],
    circles: [:subject_circles, :exclude_subject_circles],
    save_preset: []
  ]

  @doc "Optional heading rendered above the rows (eg. \"Refine\"); the Reset action sits on the same line."
  prop title, :string, default: nil
  prop show_reset, :boolean, default: true
  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop context_key, :any, default: nil
  prop apply_to, :any, default: :parent
  prop description, :string, default: nil
  prop object_types, :list, default: [:post, :article, "Edition", :Event]
  prop media_types, :list, default: [:link, :image, :video, :audio, :research]
  prop feed_filters, :any, default: nil

  prop sections, :list, default: Keyword.keys(@filter_fields)

  @doc "Available editor sections, so hosts can omit controls they already provide."
  def sections, do: Keyword.keys(@filter_fields)

  data pending_filters, :map, default: nil
  # Applied filters and host context identify the draft.
  data init_state, :any, default: nil
  # lists of %{id: uid, name: name} maps, shown as LiveSelect tags
  data selected_authors, :list, default: []
  data selected_excluded_authors, :list, default: []
  # raw text inputs (parsed into pending_filters on change, kept raw so typing isn't janky)
  data pending_tags_text, :string, default: ""
  data pending_instances_text, :string, default: ""

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    context = assigns[:__context__] || socket.assigns[:__context__]
    sections = socket.assigns.sections

    filters = Enums.maybe_to_map(e(assigns, :feed_filters, nil) || socket.assigns[:feed_filters]) || %{}

    state = {filters, {socket.assigns.context_key, sections}}

    # Preserve drafts across parent re-renders, but not across applied-filter or context changes.
    socket =
      if socket.assigns[:init_state] == state do
        socket
      else
        my_circles =
          if :circles in sections and context do
            Bonfire.UI.Boundaries.SetBoundariesLive.circles_for_multiselect(
              context,
              :subject_circles
            ) || []
          else
            []
          end

        assign(socket,
          init_state: state,
          pending_filters: filters,
          my_circles: my_circles,
          selected_authors: load_authors(filters[:subjects]),
          selected_excluded_authors: load_authors(filters[:exclude_subjects]),
          pending_tags_text:
            filters[:tags] |> List.wrap() |> Enum.map_join(" ", &("#" <> to_string(&1))),
          pending_instances_text:
            case filters[:origin] do
              domains when is_list(domains) and domains not in [[:local], [:remote]] ->
                Enum.join(domains, ", ")

              _ ->
                ""
            end
        )
      end

    {:ok,
     socket
     |> assign(sections: sections)
     |> assign_derived()}
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

  # --- Feed-style filters ---

  def handle_event("set_filter", %{"time_limit" => time_limit} = _attrs, socket) do
    {:noreply, update_pending(socket, :time_limit, Types.maybe_to_integer(time_limit))}
  end

  def handle_event("set_filter", %{"sort_order" => sort_order}, socket) do
    {:noreply, update_pending(socket, :sort_order, maybe_to_atom(sort_order))}
  end

  def handle_event("set_filter", %{"origin" => "all"}, socket) do
    {:noreply,
     socket
     |> assign(pending_instances_text: "")
     |> update_pending_fn(&Map.delete(&1, :origin))}
  end

  def handle_event("set_filter", %{"origin" => origin}, socket) do
    {:noreply,
     socket
     |> assign(pending_instances_text: "")
     |> update_pending(:origin, maybe_to_atom(origin))}
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

    socket =
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
     end)

    socket =
      if include_field == :subjects do
        assign(socket,
          selected_authors: load_authors(socket.assigns.pending_filters[:subjects]),
          selected_excluded_authors: load_authors(socket.assigns.pending_filters[:exclude_subjects])
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("set_filter", attrs, socket) do
    {:noreply,
     update_pending_fn(socket, fn filters ->
       Enums.merge_as_map(filters, Enums.naughty_to_atoms!(attrs))
     end)}
  end

  # media quick actions: "Any media" = every media type set to only; "No preference" clears
  def handle_event("any_media", _params, socket) do
    {:noreply,
     update_pending_fn(socket, fn filters ->
       filters
       |> Map.put(:media_types, socket.assigns.media_types)
       |> Map.put(:exclude_media_types, [])
     end)}
  end

  def handle_event("clear_media", _params, socket) do
    {:noreply,
     update_pending_fn(socket, fn filters ->
       filters |> Map.put(:media_types, []) |> Map.put(:exclude_media_types, [])
     end)}
  end

  def handle_event("reset_pending", _params, socket) do
    {:noreply,
     socket
     |> assign(
       pending_filters: reset_filters(socket.assigns.pending_filters, socket.assigns.sections),
       selected_authors: [],
       selected_excluded_authors: [],
       pending_tags_text: "",
       pending_instances_text: ""
     )
     |> assign_derived()}
  end

  # --- People: include / exclude authors (tags-mode LiveSelect pickers) ---

  def handle_event("live_select_change", %{"id" => ls_id, "text" => search}, socket)
      when is_binary(search) and byte_size(search) >= 2 do
    options =
      maybe_apply(Bonfire.Me.Users, :search, [search], fallback_return: [])
      |> Enum.map(fn
        %Needle.Pointer{activity: %{object: user}} -> user
        other -> other
      end)
      # Keep the display label with each selection so the picker need not reload it.
      |> Enum.map(fn user ->
        {author_label(user),
         %{
           id: id(user),
           name: author_label(user),
           username: e(user, :character, :username, nil),
           type: "user"
         }}
      end)

    maybe_send_update(LiveSelect.Component, ls_id, options: options)

    {:noreply, socket}
  end

  def handle_event("live_select_change", _params, socket), do: {:noreply, socket}

  # tags-mode LiveSelect: every selection change sends the whole current tag list
  # in the form params, so just resync the authors + the subjects filter from it
  def handle_event("multi_select", params, socket) do
    {:noreply, sync_authors(socket, params, "include_people", :selected_authors, :subjects)}
  end

  def handle_event("multi_select_exclude", params, socket) do
    {:noreply, sync_authors(socket, params, "exclude_people", :selected_excluded_authors, :exclude_subjects)}
  end

  # --- Hashtags & specific instances (free-text, comma/space separated) ---

  def handle_event("set_tags", params, socket) do
    text = e(params, "tags_text", "")
    tags = text |> split_words() |> normalise_list(&FeedFilters.normalise_tag/1)

    {:noreply,
     socket
     |> assign(pending_tags_text: text || "")
     |> update_pending_fn(fn filters ->
       if tags == [], do: Map.delete(filters, :tags), else: Map.put(filters, :tags, tags)
     end)}
  end

  def handle_event("set_instances", params, socket) do
    text = e(params, "instances_text", "")
    domains = text |> split_words() |> normalise_list(&FeedFilters.normalise_instance_domain/1)

    {:noreply,
     socket
     |> assign(pending_instances_text: text || "")
     |> update_pending_fn(fn filters ->
       cond do
         domains != [] -> Map.put(filters, :origin, domains)
         # emptied the input: fall back to "other instances" (the input only shows there)
         is_list(filters[:origin]) -> Map.put(filters, :origin, :remote)
         true -> filters
       end
     end)}
  end

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

  # list entries may be atoms, strings, ids, or loaded objects (e.g. exclude_subjects can
  # hold user structs from a saved feed) — compare their normalized string forms
  defp same_type?(entry, type) do
    to_string(Enums.id(entry) || entry) == to_string(Enums.id(type) || type)
  end

  @doc """
  Clears editable rows while retaining the host's other scope constraints.

      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.reset_filters(%{subjects: ["owner"], in_feeds: ["notifications"], time_limit: 7, media_types: [:image]}, [:time_range, :media_types])
      %{subjects: ["owner"], in_feeds: ["notifications"]}
  """
  def reset_filters(filters, sections) do
    keys = sections |> Enum.flat_map(&Keyword.get(@filter_fields, &1, []))
    Map.drop(filters, keys)
  end

  defp sync_authors(socket, params, field, assign_key, filter_key) do
    authors = extract_selected_authors(params, "#{socket.assigns.id}_#{field}")

    socket
    |> assign(assign_key, authors)
    |> update_pending_fn(fn filters ->
      case Enum.map(authors, & &1.id) do
        [] -> Map.delete(filters, filter_key)
        ids -> Map.put(filters, filter_key, ids)
      end
    end)
  end

  @doc """
  Reads the named UserSelectorLive field, ignoring text-input and unrelated form values.

      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.extract_selected_authors(%{"multi_select" => %{"other" => ["ignored"]}}, "people")
      []
  """
  def extract_selected_authors(params, field) do
    params
    |> get_in(["multi_select", field])
    |> List.wrap()
    |> Enum.flat_map(&normalise_author/1)
    |> Enum.filter(&Types.is_uid?(&1.id))
    |> Enum.uniq_by(& &1.id)
  end

  defp normalise_author(%{} = m) do
    case e(m, :id, nil) || e(m, "id", nil) do
      nil -> []
      author_id -> [%{id: author_id, name: e(m, :name, nil) || e(m, "name", nil) || author_id}]
    end
  end

  defp normalise_author("{" <> _ = json) do
    case Jason.decode(json) do
      {:ok, %{} = m} -> normalise_author(m)
      _ -> []
    end
  end

  defp normalise_author(author_id) when is_binary(author_id),
    do: [%{id: author_id, name: author_id}]

  defp normalise_author(_), do: []

  defp load_authors(nil), do: []

  defp load_authors(entries) do
    case Enums.ids(List.wrap(entries)) do
      [] ->
        []

      ids ->
        maybe_apply(Bonfire.Me.Users, :by_ids, [ids], fallback_return: [])
        |> Enum.map(&%{id: id(&1), name: author_label(&1)})
    end
  end

  defp author_label(user) do
    e(user, :profile, :name, nil) || e(user, :character, :username, nil) || id(user)
  end

  defp split_words(text), do: String.split(text || "", [",", " ", "\n"], trim: true)

  defp normalise_list(values, fun),
    do: values |> Enum.map(fun) |> Enum.reject(&is_nil/1) |> Enum.uniq()

  # --- Row value summaries (the collapsed state of each row) ---

  @doc "True when the current :origin filter matches the given option (`:all`, `:local`, `:remote`)."
  def origin_matches?(filters, :all), do: e(filters, :origin, nil) in [nil, :all]
  def origin_matches?(filters, origin), do: e(filters, :origin, nil) in [origin, [origin]]

  @doc "The specific-instances input is only offered once 'Other instances' is chosen."
  def show_instances?(filters) do
    case e(filters, :origin, nil) do
      :remote -> true
      [:remote] -> true
      [local] when local in [:local, "local"] -> false
      domains when is_list(domains) and domains != [] -> true
      _ -> false
    end
  end

  @doc "Collapsed value for the origin row."
  def origin_summary(filters) do
    case e(filters, :origin, nil) do
      origin when origin in [nil, :all] -> l("Anywhere")
      origin when origin in [:local, [:local]] -> l("This instance")
      origin when origin in [:remote, [:remote]] -> l("Other instances")
      domains when is_list(domains) -> summarise_list(domains, &to_string/1, 1)
      _ -> l("Anywhere")
    end
  end

  @doc "Collapsed value for the people rows: first names, two shown then +N; or a count for exclusions."
  def people_summary(authors, :include) do
    case authors do
      [] -> l("Anyone")
      list -> summarise_list(list, &first_name(&1.name), 2)
    end
  end

  def people_summary(authors, :exclude) do
    case length(authors) do
      0 -> l("No one")
      n -> l("%{count} excluded", count: n)
    end
  end

  defp first_name(name) do
    name |> to_string() |> String.split() |> List.first() || ""
  end

  @doc "Collapsed value for the hashtags row."
  def hashtags_summary(filters) do
    case List.wrap(e(filters, :tags, [])) do
      [] -> l("Any")
      tags -> summarise_list(tags, &("#" <> to_string(&1)), 2)
    end
  end

  # "a, b +N"
  defp summarise_list(list, fmt, max) do
    shown = list |> Enum.take(max) |> Enum.map_join(", ", fmt)
    rest = length(list) - max
    if rest > 0, do: "#{shown} +#{rest}", else: shown
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

  @doc """
  Whether a type dimension has an include or exclude selection, independent of its translated label.

      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.types_filtered?(%{exclude_media_types: [:image]}, :media_types)
      true
      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.types_filtered?(%{}, :media_types)
      false
  """
  def types_filtered?(filters, field) do
    List.wrap(e(filters, field, [])) != [] or
      List.wrap(e(filters, maybe_to_atom("exclude_#{field}"), [])) != []
  end

  @doc """
  Whether the selected types exactly match the host's available media types, with no exclusions.

      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.any_media?(%{media_types: ["image", "research"]}, [:image, :research])
      true
      iex> Bonfire.UI.Social.FeedFiltersModalContentLive.any_media?(%{media_types: [:image]}, [:image, :research])
      false
  """
  def any_media?(filters, media_types) do
    only = filters |> e(:media_types, []) |> List.wrap() |> MapSet.new(&to_string/1)
    available = MapSet.new(media_types, &to_string/1)
    media_types != [] and only == available and
      List.wrap(e(filters, :exclude_media_types, [])) == []
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

  @doc "Collapsed value for the media row: 'Any media' when every type is isolated, else names."
  def media_summary(filters, media_types) do
    only = List.wrap(e(filters, :media_types, [])) |> Enum.map(&to_string/1)
    hide = List.wrap(e(filters, :exclude_media_types, [])) |> Enum.map(&to_string/1)

    cond do
      any_media?(filters, media_types) -> l("Any media")
      only == [] and hide == [] -> l("Any")
      true ->
        [
          if(only != [], do: Enum.map_join(only, ", ", &String.capitalize/1)),
          if(hide != [], do: l("no %{types}", types: Enum.join(hide, ", ")))
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" · ")
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
    update_pending_fn(socket, &Map.put(&1, key, value))
  end

  defp update_pending_fn(socket, fun) do
    pending = socket.assigns[:pending_filters] || %{}
    socket
    |> assign(:pending_filters, fun.(pending))
    |> assign_derived()
  end

  defp assign_derived(socket) do
    filters = socket.assigns[:pending_filters] || %{}
    context = socket.assigns[:__context__]

    assign(socket,
      active_filters: Bonfire.UI.Social.FeedControlsLive.active_filters(filters, context),
      user_activities_excluded?:
        Bonfire.UI.Social.FeedExtraControlsLive.user_activities_excluded?(filters, context),
      preset_origin_info:
        Bonfire.UI.Social.FeedExtraControlsLive.get_preset_origin_info(filters, context)
    )
  end
end
