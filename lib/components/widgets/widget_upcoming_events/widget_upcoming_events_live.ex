defmodule Bonfire.UI.Social.WidgetUpcomingEventsLive do
  @moduledoc """
  A widget displaying upcoming events sorted by startTime.

  Shows events where startTime > now, limited to the next 5 upcoming events
  from the user's event feed.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.DatesTimes
  alias Bonfire.Social.FeedActivities
  alias Bonfire.Data.Social.APActivity

  import Untangle

  prop limit, :integer, default: 5
  prop widget_title, :string, default: nil

  @doc """
  Loads upcoming events for the widget.

  Returns a keyword list with :events key containing the list of upcoming events,
  or an empty list if no events are found.
  """
  def load(current_user, limit \\ 5) do
    result =
      FeedActivities.feed(
        %{feed_name: :events},
        current_user: current_user,
        paginate: %{limit: limit * 3},
        preload: [:with_subject]
      )

    case result do
      %{edges: edges} when is_list(edges) and edges != [] ->
        # Get object IDs to load APActivity records
        object_ids =
          edges
          |> Enum.map(&e(&1, :activity, :object_id, nil))
          |> Enum.reject(&is_nil/1)

        # Load APActivity records with their JSON
        ap_activities =
          if object_ids != [] do
            import Ecto.Query
            Bonfire.Common.Repo.all(
              from(a in APActivity, where: a.id in ^object_ids, select: {a.id, a.json})
            )
            |> Map.new()
          else
            %{}
          end

        now = DateTime.utc_now()

        upcoming =
          edges
          |> Enum.map(fn edge ->
            object_id = e(edge, :activity, :object_id, nil)
            json = Map.get(ap_activities, object_id, %{})
            # Attach json to edge for later use
            Map.put(edge, :event_json, json)
          end)
          |> Enum.filter(&future_event?(&1, now))
          |> Enum.sort_by(
            &extract_start_time/1,
            fn
              nil, nil -> true
              nil, _ -> false
              _, nil -> true
              a, b -> DateTime.compare(a, b) != :gt
            end
          )
          |> Enum.take(limit)

        [events: upcoming]

      _other ->
        [events: []]
    end
  end

  @doc """
  Gets the event JSON from edge (either from :event_json we attached, or fallback paths).
  """
  def get_event_json(edge) do
    e(edge, :event_json, nil) ||
      e(edge, :activity, :object, :json, nil) ||
      e(edge, :object, :json, nil) ||
      e(edge, :json, nil) ||
      %{}
  end

  @doc """
  Gets a field from the event JSON.
  Handles both nested "object" structure and flat structure.
  """
  def object_field(json, field) when is_map(json) do
    e(json, "object", field, nil) || e(json, field, nil)
  end

  def object_field(_, _), do: nil

  @doc """
  Extracts the startTime from an event edge as a DateTime.
  Returns nil if startTime is not present or invalid.
  """
  def extract_start_time(edge) do
    json = get_event_json(edge)

    case object_field(json, "startTime") do
      nil ->
        nil

      start_time_str when is_binary(start_time_str) ->
        case DateTime.from_iso8601(start_time_str) do
          {:ok, dt, _offset} -> dt
          _ -> nil
        end
    end
  end

  @doc """
  Checks if an event is in the future (startTime > now).
  """
  def future_event?(edge, now) do
    case extract_start_time(edge) do
      nil -> false
      dt -> DateTime.compare(dt, now) == :gt
    end
  end

  @doc """
  Formats the event start time for display.
  Shows relative time (Today, Tomorrow, weekday) for near events,
  or formatted date for events further out.
  """
  def format_relative_time(nil), do: nil

  def format_relative_time(dt) do
    today = Date.utc_today()
    date = DateTime.to_date(dt)
    days_diff = Date.diff(date, today)
    time_str = format_time(dt)

    cond do
      days_diff == 0 ->
        Gettext.gettext(Bonfire.Common.Localise.Gettext, "Today at %{time}", time: time_str)

      days_diff == 1 ->
        Gettext.gettext(Bonfire.Common.Localise.Gettext, "Tomorrow at %{time}", time: time_str)

      days_diff > 1 and days_diff < 7 ->
        day_name = Calendar.strftime(dt, "%A")

        Gettext.gettext(Bonfire.Common.Localise.Gettext, "%{day} at %{time}",
          day: day_name,
          time: time_str
        )

      true ->
        date_str = Calendar.strftime(dt, "%b %d")

        Gettext.gettext(Bonfire.Common.Localise.Gettext, "%{date} at %{time}",
          date: date_str,
          time: time_str
        )
    end
  end

  defp format_time(dt) do
    Calendar.strftime(dt, "%-I:%M %p")
  end

  @doc """
  Gets the location text from an event, if present.
  """
  def event_location(edge) do
    json = get_event_json(edge)
    location = object_field(json, "location")

    case location do
      %{"name" => name} when is_binary(name) and name != "" ->
        name

      %{"address" => %{"streetAddress" => addr}} when is_binary(addr) and addr != "" ->
        addr

      %{"address" => %{"addressLocality" => locality}} when is_binary(locality) and locality != "" ->
        locality

      _ ->
        nil
    end
  end

  @doc """
  Gets the event URL for linking.
  """
  def event_url(edge) do
    json = get_event_json(edge)
    object_field(json, "id")
  end

  @doc """
  Gets the event name/title.
  """
  def event_name(edge) do
    json = get_event_json(edge)
    object_field(json, "name")
  end

  @doc """
  Gets the event ID for internal linking.
  """
  def event_id(edge) do
    e(edge, :activity, :object_id, nil) || e(edge, :object, :id, nil) || e(edge, :id, nil)
  end
end
