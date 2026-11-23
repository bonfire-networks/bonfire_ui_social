defmodule Bonfire.UI.Social.WidgetCustomizeFeedLive do
  @moduledoc """
  Feed preferences separate ordering from content inclusion. Detailed filters are mounted only when expanded; all changes are handled by the owning FeedLive component.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.FeedExtraControlsLive

  prop widget_title, :string, default: nil

  @doc "DOM selector of the feed component (e.g. `\"#feed_component_id\"`) that filter events are sent to."
  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil

  @doc "Keys of the controls not to show: the sort row (`:sort_by`, eg. on a map, whose markers have no order), the content switches (`override_rows/2`), eg. `[:group_activity]` on a feed that is only group activities, as `FeedExtraControlsLive`'s `hide_filters` does for its own, and the sections of the \"More filters\" editor (`FeedFiltersModalContentLive.sections/0`), eg. `:activity_types`. A key that is neither is ignored"
  prop hide_filters, :list, default: []

  @doc "Sections of the \"More filters\" editor (`FeedFiltersModalContentLive.sections/0`) to show above it instead, as the same rows, eg. `[:happening, :nearby]` on a page of events. They apply as soon as they change, as the sort and the switches do, and are not in \"More filters\" too. Keys in `hide_filters` stay hidden"
  prop top_sections, :list, default: []

  @doc "Whether the feed can be saved as a custom feed: false for a preset with its own query (`base_query_fun`), as only filters carry over to a saved feed"
  prop can_save, :boolean, default: true

  data initial_preferences, :any, default: nil
  data default_preferences, :any, default: nil
  data reset_revision, :integer, default: 0

  def handle_event("reset_preferences", _, %{assigns: %{event_target: "#" <> feed_id}} = socket) do
    Phoenix.LiveView.send_update(Bonfire.UI.Social.FeedLive, id: feed_id, reset_preferences: true)
    {:noreply, assign(socket, reset_revision: socket.assigns.reset_revision + 1)}
  end

  # a host that is a LiveView, not a feed component (no `event_target`), gets the reset as a message, as it gets the filters applied from the editor
  def handle_event("reset_preferences", _, %{assigns: %{event_target: nil}} = socket) do
    send(self(), {__MODULE__, :reset})
    {:noreply, assign(socket, reset_revision: socket.assigns.reset_revision + 1)}
  end

  def update(%{preferences: preferences}, socket) do
    {:ok,
     socket
     |> assign(preferences)
     |> assign(
       default_preferences: socket.assigns[:default_preferences] || preferences[:feed_filters]
     )}
  end

  def update(assigns, socket) do
    initial_preferences = Map.take(assigns, [:event_target, :feed_name, :feed_filters])

    # A parent re-render carries the original props; only a new page selection resets live values.
    if socket.assigns.initial_preferences == initial_preferences do
      {:ok, assign(socket, Map.drop(assigns, [:feed_name, :feed_filters]))}
    else
      {:ok,
       socket
       |> assign(assigns)
       |> assign(initial_preferences: initial_preferences, default_preferences: nil)}
    end
  end

  @doc """
  Whether preferences differ from their initial values, ignoring equivalent filter representations.

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.preferences_changed?(%{sort_by: :date_created, sort_order: :desc}, %{})
      false

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.preferences_changed?(%{sort_order: :asc}, %{})
      true

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.preferences_changed?(%{exclude_activity_types: [:reply]}, %{})
      true

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.preferences_changed?(%{sort_by: :like_count, sort_order: :asc}, %{sort_by: :like_count, sort_order: :desc})
      true

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.preferences_changed?(%{sort_by: :like_count, sort_order: "desc"}, %{sort_by: :like_count})
      false
  """
  def preferences_changed?(filters, defaults) do
    current_order(filters) != current_order(defaults) or
      not Bonfire.Social.Feeds.LiveHandler.filter_value_matches?(
        e(filters, :sort_order, :desc),
        e(defaults, :sort_order, :desc)
      ) or
      Enum.any?(
        Bonfire.Social.FeedFilters.supported_filters() -- [:feed_name, :sort_by, :sort_order],
        fn key ->
          not Bonfire.Social.Feeds.LiveHandler.filter_value_matches?(
            e(filters, key, nil),
            e(defaults, key, nil)
          )
        end
      )
  end

  @doc "Order choices supported by the feed loader, independent of content filters. With the feed's `filters`, it also offers the order of the dates things happen on (eg. events) when there is a Happening filter or the feed is of events only: things without dates have no start to sort by."
  def order_options(filters \\ nil) do
    [
      {"newest", l("Newest first")},
      {"oldest", l("Oldest first")}
    ] ++
      if(starts_sort_offered?(filters),
        do: [{"starts_at", Bonfire.UI.Social.SortItemsDropdownLive.starts_sort_label(filters)}],
        else: []
      ) ++
      [
        {"reply_count", l("Most replied")},
        {"boost_count", l("Most boosted")},
        {"like_count", l("Most liked")},
        {"latest_reply", l("Latest reply")},
        {"popularity_score", l("Popularity")}
      ]
  end

  defp starts_sort_offered?(filters) do
    Bonfire.UI.Social.SortItemsDropdownLive.starts_sort?(filters) or events_only?(filters)
  end

  defp events_only?(filters) do
    case List.wrap(e(filters, :object_types, nil) || []) do
      [] -> false
      types -> Enum.all?(types, &(to_string(&1) in ["Event", "event"]))
    end
  end

  @doc "The selected order, including ordering configured through the detailed editor."
  def current_order(filters) do
    case e(filters, :sort_by, nil) do
      sort when sort in [nil, false, :date_created, "date_created", "false"] ->
        if e(filters, :sort_order, :desc) in [:asc, "asc"], do: "oldest", else: "newest"

      sort ->
        to_string(sort)
    end
  end

  @doc """
  Updates only ordering, adding a one-week window for ranking when no range is set.

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.order_filters("newest", %{})
      %{sort_by: :date_created, sort_order: :desc}

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.order_filters("reply_count", %{time_limit: 30})
      %{sort_by: :reply_count, sort_order: :desc}

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.order_filters("boost_count", %{})
      %{sort_by: :boost_count, sort_order: :desc, time_limit: 7}

      iex> Bonfire.UI.Social.WidgetCustomizeFeedLive.order_filters("unknown", %{})
      nil
  """
  def order_filters("newest", _filters), do: %{sort_by: :date_created, sort_order: :desc}
  def order_filters("oldest", _filters), do: %{sort_by: :date_created, sort_order: :asc}

  # earliest start first, or latest first when looking at what has passed
  def order_filters("starts_at", filters),
    do: %{
      sort_by: :starts_at,
      sort_order: if(e(filters, :time_span, nil) in [:past, "past"], do: :desc, else: :asc)
    }

  def order_filters(value, filters) do
    case Enum.find(
           [:reply_count, :boost_count, :like_count, :latest_reply, :popularity_score],
           &(to_string(&1) == value)
         ) do
      nil ->
        nil

      sort ->
        attrs = %{sort_by: sort, sort_order: :desc}

        if sort != :latest_reply and e(filters, :time_limit, nil) == nil,
          do: Map.put(attrs, :time_limit, 7),
          else: attrs
    end
  end

  @doc "Common content inclusion controls, independent of ordering and source, less the keys in `hide_filters`."
  def override_rows(feed_filters, hide_filters \\ []) do
    hidden = Enum.map(List.wrap(hide_filters), &to_string/1)

    [
      %{
        key: :replies,
        name: l("Replies"),
        on: not FeedExtraControlsLive.replies_excluded?(feed_filters)
      },
      %{
        key: :boosts,
        name: l("Boosts"),
        on: not FeedExtraControlsLive.boosts_excluded?(feed_filters)
      },
      %{
        key: :group_activity,
        name: l("Group activities"),
        on: group_activities_included?(feed_filters)
      }
    ]
    |> Enum.reject(&(to_string(&1.key) in hidden))
  end

  # spellings under which a group/category subject-type exclusion may be stored
  # (we store `:group`; the modal or saved feeds may carry other aliases)
  @group_subject_types [
    "group",
    "groups",
    "category",
    "categories",
    "Group",
    "Category",
    "Elixir.Bonfire.Classify.Category",
    "2AGSCANBECATEG0RY0RHASHTAG"
  ]

  @doc "Whether group/category-authored activities and objects published in a category context are included (the default is true). The switch writes the compound `exclude_group_activities` flag; the other keys are legacy per-dimension spellings from saved feeds or the advanced modal."
  def group_activities_included?(feed_filters) do
    not e(feed_filters, :exclude_group_activities, false) and
      not e(feed_filters, :exclude_category_contexts, false) and
      List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
      |> Enum.all?(&(to_string(&1) not in @group_subject_types))
  end

  @doc """
  The filter updates for switching Group activities on or off — the single place that knows
  which keys the exclusion involves (pair of `group_activities_included?/1`).

  OFF stores just the compound `exclude_group_activities` flag (expanded at query time by
  `FeedLoader.prepare_filters_and_opts`, so no other filter surface can half-clear it);
  ON clears the flag and also sweeps any legacy per-dimension spellings.
  """
  def group_activities_toggle_filters(_feed_filters, false),
    do: %{exclude_group_activities: true}

  def group_activities_toggle_filters(feed_filters, true) do
    %{
      exclude_group_activities: false,
      exclude_subject_types:
        List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
        |> Enum.reject(&(to_string(&1) in @group_subject_types)),
      exclude_category_contexts: false
    }
  end
end
