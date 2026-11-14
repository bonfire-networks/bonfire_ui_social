defmodule Bonfire.UI.Social.Activity.EventActivityStreamsLive do
  @moduledoc """
  Deprecated as the main event card: events are native `Bonfire.Gatherings.Event`s when `bonfire_gatherings` is enabled, shown by `Bonfire.Gatherings.Web.Preview.EventLive`.

  Kept as the simplified fallback for when it is not: nothing then claims the `Event` type, so incoming events are stored as `APActivity`s, and this card shows them from their AS2 json (as it does for APActivity events not yet converted).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.DatesTimes
  # alias Bonfire.Social.Events

  prop json, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop showing_within, :any, default: nil
  prop viewing_main_object, :boolean, default: nil

  # # AS2 parsing is owned by the `Bonfire.Social.Events` context; these thin
  # # delegates keep the template call-sites terse and the parsing single-sourced.
  # defdelegate object_field(json, field), to: Events
  # defdelegate source_url(json), to: Events
  # defdelegate source_host(url), to: Events
  # defdelegate event_time(iso), to: Events, as: :parse_time
  # defdelegate event_end_time(json), to: Events, as: :end_time
  # the AS2 accessors moved here from `Bonfire.Social.Events`, as this card was their only user

  @doc """
  A field from an AS2 `Event` map, handling both the nested `object` shape and the flat shape.

  ## Examples

      iex> object_field(%{"name" => "Flat"}, "name")
      "Flat"

      iex> object_field(%{"object" => %{"name" => "Nested"}}, "name")
      "Nested"

      iex> object_field(nil, "name")
      nil
  """
  def object_field(json, field) when is_map(json) do
    e(json, "object", field, nil) || e(json, field, nil)
  end

  def object_field(_, _), do: nil

  @doc """
  The event's title (`name`), or nil.

  ## Examples

      iex> title(%{"name" => "Launch Party"})
      "Launch Party"

      iex> title(%{})
      nil
  """
  def title(json), do: object_field(json, "name")

  @doc """
  Parse an ISO8601 event time into the data the UI needs.

  Restores the event's *original* local wall-clock time (federated events carry their own timezone), so a 17:00 event reads as 17:00 regardless of the viewer's zone, and keeps the raw ISO string for a machine-readable `<time datetime=…>`. Returns `%{iso: binary, local: DateTime.t(), offset: integer}` or `nil`.

  ## Examples

      iex> event_time("2026-06-08T13:00:00+02:00")
      %{iso: "2026-06-08T13:00:00+02:00", local: ~U[2026-06-08 13:00:00Z], offset: 7200}

      iex> event_time("not a date")
      nil

      iex> event_time(nil)
      nil
  """
  def event_time(iso) when is_binary(iso) do
    with {:ok, datetime, offset} <- DateTime.from_iso8601(iso) do
      %{iso: iso, local: DateTime.add(datetime, offset, :second), offset: offset}
    else
      _ -> nil
    end
  end

  def event_time(_), do: nil

  @doc """
  Parsed start time of an event (see `event_time/1`), or nil.

  ## Examples

      iex> start_time(%{"startTime" => "2026-06-08T13:00:00Z"}).local
      ~U[2026-06-08 13:00:00Z]

      iex> start_time(%{})
      nil
  """
  def start_time(json), do: json |> object_field("startTime") |> event_time()

  @doc """
  Parsed end time of an event, or nil when there's no end or it's marked hidden (`displayEndTime == "false"`).

  ## Examples

      iex> event_end_time(%{"endTime" => "2026-06-08T15:00:00Z"}).local
      ~U[2026-06-08 15:00:00Z]

      iex> event_end_time(%{"endTime" => "2026-06-08T15:00:00Z", "displayEndTime" => "false"})
      nil

      iex> event_end_time(%{})
      nil
  """
  def event_end_time(json) do
    if object_field(json, "displayEndTime") != "false" do
      json |> object_field("endTime") |> event_time()
    end
  end

  @doc """
  A concise location string for an event (venue name, else street address, else locality), or nil.

  ## Examples

      iex> location_name(%{"location" => %{"name" => "The Barn"}})
      "The Barn"

      iex> location_name(%{"location" => %{"address" => %{"addressLocality" => "Berlin"}}})
      "Berlin"

      iex> location_name(%{})
      nil
  """
  def location_name(json) do
    case object_field(json, "location") do
      %{"name" => name} when is_binary(name) and name != "" ->
        name

      %{"address" => %{"streetAddress" => addr}} when is_binary(addr) and addr != "" ->
        addr

      %{"address" => %{"addressLocality" => locality}}
      when is_binary(locality) and locality != "" ->
        locality

      _ ->
        nil
    end
  end

  @doc """
  The event's link for humans: its `url`, falling back to the AP `id`.

  The `id` is the canonical ActivityPub identifier and often serves JSON rather than a page, so it is
  only a last resort. An AS2 `url` may be a plain string, a `Link` object, or a list of either.

  ## Examples

      iex> source_url(%{"id" => "https://gancio.cisti.org/federation/m/42", "url" => "https://gancio.cisti.org/event/42"})
      "https://gancio.cisti.org/event/42"

      iex> source_url(%{"url" => %{"type" => "Link", "href" => "https://example.org/event/1"}})
      "https://example.org/event/1"

      iex> source_url(%{"id" => "https://example.org/event/42"})
      "https://example.org/event/42"

      iex> source_url(%{})
      nil
  """
  def source_url(json) do
    json |> object_field("url") |> href() || object_field(json, "id")
  end

  defp href(url) when is_binary(url), do: url
  defp href(%{"href" => href}) when is_binary(href), do: href
  defp href([_ | _] = urls), do: Enum.find_value(urls, &href/1)
  defp href(_), do: nil

  @doc """
  Host of a source URL, for the read-only "View on …" link (e.g. `"gancio.cisti.org"`), or nil.

  ## Examples

      iex> source_host("https://gancio.cisti.org/event/42")
      "gancio.cisti.org"

      iex> source_host(nil)
      nil
  """
  def source_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  def source_host(_), do: nil

  # moved to `Bonfire.Common.DatesTimes`, which the native event card uses too (the bodies that were here are the same there)
  defdelegate format_range(start_t, end_t \\ nil), to: DatesTimes
  defdelegate chip_parts(time), to: DatesTimes
end
