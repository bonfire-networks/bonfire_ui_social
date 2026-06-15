defmodule Bonfire.UI.Social.EventsLive do
  @moduledoc """
  The `/events` discovery page: a "Browse by Category" grid (FEP-8a8e categories
  present in the events, with live counts) that filters a chronological,
  day-grouped agenda. Agenda items render via `ActivityLive` + a `custom_preview`
  (`EventPreviewLive`) for the standard preview-on-click.

  Events are `APActivity` rows whose `json` holds an AS2 `Event` (e.g. federated
  from Mobilizon/Gancio). Per-event data: `EventHelpers` (aliased `EV`); category
  labels/order: `EventCategories`.
  """
  use Bonfire.UI.Common.Web, :surface_live_view

  import Ecto.Query
  alias Bonfire.Social.FeedActivities
  alias Bonfire.Data.Social.APActivity
  alias Bonfire.Common.DatesTimes
  alias Bonfire.UI.Social.EventHelpers, as: EV
  alias Bonfire.UI.Social.EventCategories

  # Paged through the ULID-ordered feed and accumulated, then dated & sorted in
  # memory (the DB can't order by the startTime buried in the AS2 json).
  @per_page 50
  defp per_page, do: Config.get([__MODULE__, :per_page], @per_page)

  @doc "Categories that have at least one event, most-populated first (FEP-8a8e)."
  def categories(counts \\ %{}) do
    EventCategories.all()
    |> Enum.filter(&(category_count(counts, &1) > 0))
    |> Enum.sort_by(&(-category_count(counts, &1)))
  end

  declare_nav_link(l("Events"),
    icon: "ph:calendar-blank-duotone",
    page: "events",
    href: "/events"
  )

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.LoadCurrentUserCircles
            ]}

  def mount(_params, _session, socket) do
    {events, page_info} = load_events_page(current_user(socket))

    {:ok,
     socket
     |> assign(
       page: "events",
       page_title: l("Discover Events"),
       page_header_icon: "ph:calendar-blank-duotone",
       no_index: true,
       back: true,
       today: Date.utc_today(),
       selected_category: nil,
       events: events,
       page_info: page_info,
       category_counts: category_counts(events),
       feedback_title: l("No events found"),
       feedback_message:
         l(
           "Events from people you follow and federated platforms like Mobilizon will appear here."
         ),
       sidebar_widgets: [
         users: [
           secondary: [{Bonfire.Tag.Web.WidgetTagsLive, []}]
         ],
         guests: [
           secondary: [{Bonfire.Tag.Web.WidgetTagsLive, []}]
         ]
       ]
     )}
  end

  def handle_event("select_category", %{"category" => category}, socket) do
    selected = toggle(socket.assigns.selected_category, EV.normalize_category(category))
    {:noreply, assign(socket, selected_category: selected)}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, assign(socket, selected_category: nil)}
  end

  def handle_event("load_more", attrs, socket) do
    cursor = e(input_to_atoms(attrs), :after, nil)
    {new_events, page_info} = load_events_page(current_user(socket), cursor)

    merged =
      (e(socket.assigns, :events, []) ++ new_events)
      |> Enum.uniq_by(&(e(&1, :id, nil) || e(&1, :activity, :id, nil)))
      # re-sort: new pages arrive in ULID order, not by event date
      |> Enum.sort_by(& &1.start_at, NaiveDateTime)

    {:noreply,
     assign(socket,
       events: merged,
       page_info: page_info,
       category_counts: category_counts(merged)
     )}
  end

  defp load_events_page(current_user, cursor \\ nil) do
    limit = per_page()
    paginate = if cursor, do: %{limit: limit, after: cursor}, else: %{limit: limit}

    case FeedActivities.feed(%{feed_name: :events},
           current_user: current_user,
           paginate: paginate,
           preload: [:with_subject]
         ) do
      %{edges: edges, page_info: page_info} when is_list(edges) -> {date_edges(edges), page_info}
      %{edges: edges} when is_list(edges) -> {date_edges(edges), nil}
      _ -> {[], nil}
    end
  end

  # The feed resolves `activity.object` to a bare Needle pointer, so batch-load
  # the `APActivity` rows (which carry the AS2 `json`) and attach them.
  defp date_edges(edges) do
    objects = load_event_objects(edges)

    edges
    |> Enum.map(fn edge ->
      object = Map.get(objects, e(edge, :activity, :object_id, nil))

      edge
      |> Map.put(:event_object, object)
      |> Map.put(:event_json, e(object, :json, %{}))
      |> then(&Map.put(&1, :start_at, EV.event_start(&1)))
    end)
    |> Enum.filter(&match?(%NaiveDateTime{}, &1.start_at))
    |> Enum.sort_by(& &1.start_at, NaiveDateTime)
  end

  defp load_event_objects(edges) do
    ids =
      edges
      |> Enum.map(&e(&1, :activity, :object_id, nil))
      |> Enum.reject(&is_nil/1)

    if ids == [] do
      %{}
    else
      from(a in APActivity, where: a.id in ^ids)
      |> Bonfire.Common.Repo.all()
      |> Map.new(&{&1.id, &1})
    end
  end

  # %{CATEGORY => count} across all loaded events (an event may have several)
  defp category_counts(events),
    do: events |> Enum.flat_map(&EV.event_categories/1) |> Enum.frequencies()

  @doc "Event count for a category (0 if none)."
  def category_count(counts, category), do: Map.get(counts, category, 0)

  @doc "Human-friendly event count for a category card."
  def count_label(0), do: l("No events")
  def count_label(1), do: l("1 event")
  def count_label(n), do: l("%{count} events", count: n)

  @doc "Upcoming events (today onwards) after applying the active category filter."
  def filtered(events, category) do
    today = Date.utc_today()

    events
    |> Enum.filter(&(Date.compare(NaiveDateTime.to_date(&1.start_at), today) != :lt))
    |> filter_category(category)
  end

  defp filter_category(events, nil), do: events

  defp filter_category(events, category),
    do: Enum.filter(events, &(category in EV.event_categories(&1)))

  @doc "Groups (already-filtered) events by day, ascending, for date-headed sections."
  def grouped(events) do
    events
    |> Enum.group_by(&NaiveDateTime.to_date(&1.start_at))
    |> Enum.sort_by(fn {date, _} -> date end, Date)
  end

  @doc "Human-friendly section label for a day (Today/Tomorrow/date)."
  def day_label(%Date{} = date) do
    case Date.diff(date, Date.utc_today()) do
      0 -> l("Today")
      1 -> l("Tomorrow")
      -1 -> l("Yesterday")
      _ -> DatesTimes.format(date, format: "MMM d")
    end
  end

  @doc "Localised weekday name for a date (e.g. \"Monday\")."
  def weekday(%Date{} = date), do: DatesTimes.format(date, format: "EEEE")

  @doc "Activity for `ActivityLive`, with the real `APActivity` object set (the feed only gave a pointer) so the permalink resolves and the preview can read the AS2 `json`."
  def activity_for_preview(edge) do
    activity = e(edge, :activity, nil)

    case e(edge, :event_object, nil) do
      %{} = object -> Map.put(activity, :object, object)
      _ -> activity
    end
  end

  # re-selecting the same value toggles it off
  defp toggle(same, same), do: nil
  defp toggle(_current, new), do: new
end
