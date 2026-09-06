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

  data initial_preferences, :any, default: nil
  data reset_revision, :integer, default: 0

  def handle_event("reset_preferences", _, %{assigns: %{event_target: "#" <> feed_id}} = socket) do
    Phoenix.LiveView.send_update(Bonfire.UI.Social.FeedLive, id: feed_id, reset_preferences: true)
    {:noreply, assign(socket, reset_revision: socket.assigns.reset_revision + 1)}
  end

  def update(%{preferences: preferences}, socket) do
    {:ok, assign(socket, preferences)}
  end

  def update(assigns, socket) do
    initial_preferences = Map.take(assigns, [:event_target, :feed_name, :feed_filters])

    # A parent re-render carries the original props; only a new page selection resets live values.
    if socket.assigns.initial_preferences == initial_preferences do
      {:ok, assign(socket, Map.drop(assigns, [:feed_name, :feed_filters]))}
    else
      {:ok, socket |> assign(assigns) |> assign(initial_preferences: initial_preferences)}
    end
  end

  @doc "Order choices supported by the feed loader, independent of content filters."
  def order_options do
    [
      {"newest", l("Newest first")},
      {"oldest", l("Oldest first")},
      {"reply_count", l("Most replied")},
      {"boost_count", l("Most boosted")},
      {"like_count", l("Most liked")},
      {"latest_reply", l("Latest reply")},
      {"popularity_score", l("Popularity")}
    ]
  end

  @doc "The selected order, including ordering configured through the detailed editor."
  def current_order(filters) do
    case e(filters, :sort_by, nil) do
      sort when sort in [nil, false, :date_created, "date_created", "false"] ->
        if e(filters, :sort_order, :desc) in [:asc, "asc"], do: "oldest", else: "newest"

      sort -> to_string(sort)
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

  def order_filters(value, filters) do
    case Enum.find([:reply_count, :boost_count, :like_count, :latest_reply, :popularity_score], &(to_string(&1) == value)) do
      nil -> nil
      sort ->
        attrs = %{sort_by: sort, sort_order: :desc}
        if sort != :latest_reply and e(filters, :time_limit, nil) == nil,
          do: Map.put(attrs, :time_limit, 7),
          else: attrs
    end
  end

  @doc "Common content inclusion controls, independent of ordering and source."
  def override_rows(feed_filters, _feed_name, _context) do
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
