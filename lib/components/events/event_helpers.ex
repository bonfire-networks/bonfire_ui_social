defmodule Bonfire.UI.Social.EventHelpers do
  @moduledoc """
  Pure display helpers for a single event "edge" (a feed item whose `event_json`
  is an ActivityStreams `Event`, flat or nested under `"object"`). Shared by the
  `/events` page and the compact card (`EventPreviewLive`). AS2 time parsing is
  delegated to the canonical event card (`EventActivityStreamsLive`).
  """
  use Bonfire.Common.Utils

  alias Bonfire.Common.DatesTimes
  alias Bonfire.Common.Media
  alias Bonfire.Social.Events.Categories
  alias Bonfire.UI.Social.Activity.EventActivityStreamsLive, as: Card

  @doc "The AS2 Event JSON for a feed edge, trying the usual locations."
  def get_event_json(edge) do
    e(edge, :event_json, nil) ||
      e(edge, :activity, :object, :json, nil) ||
      e(edge, :object, :json, nil) ||
      e(edge, :json, nil) ||
      %{}
  end

  @doc "A field from the Event JSON, handling both nested `object` and flat shapes."
  def object_field(json, field) when is_map(json) do
    e(json, "object", field, nil) || e(json, field, nil)
  end

  def object_field(_, _), do: nil

  def event_title(edge), do: object_field(get_event_json(edge), "name") || l("Untitled event")

  @doc "Source instance host for a federated event (e.g. \"gancio.cisti.org\"), or nil."
  def event_source(edge), do: Card.source_host(event_url(edge))

  defp event_url(edge), do: object_field(get_event_json(edge), "id")

  def event_poster(edge), do: Card.poster_url(get_event_json(edge))

  @doc "A concise location string for an event edge, or nil."
  def event_location(edge) do
    case object_field(get_event_json(edge), "location") do
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

  # --- host (the activity's subject) ---

  def event_host(edge), do: e(edge, :activity, :subject, :profile, :name, nil)

  def event_host_id(edge),
    do: e(edge, :activity, :subject_id, nil) || e(edge, :activity, :subject, :id, nil)

  def event_host_avatar(edge), do: Media.avatar_url(e(edge, :activity, :subject, nil))

  @doc "Local profile path for the host, or nil."
  def event_host_path(edge) do
    case e(edge, :activity, :subject, nil) do
      nil -> nil
      subject -> Bonfire.Common.URIs.path(subject, [], preload_if_needed: false)
    end
  end

  # --- categories (FEP-8a8e) ---

  def event_categories(edge), do: edge |> get_event_json() |> Categories.from_object()

  @doc "Primary category of an event (first one), or nil."
  def event_category(edge), do: edge |> event_categories() |> List.first()

  defdelegate normalize_category(category), to: Categories, as: :normalize

  # --- times (all wall-clock, via the canonical card parser) ---

  @doc "Naive wall-clock start time of an event (or nil)."
  def event_start(edge), do: edge |> get_event_json() |> object_field("startTime") |> wall_clock()

  defp event_time_label(%{start_at: %NaiveDateTime{} = dt}), do: time_str(dt)
  defp event_time_label(_), do: nil

  @doc "Localised start–end range when same-day (e.g. \"4:00 PM – 6:00 PM\"), else just the start."
  def event_time_range(edge) do
    case {event_time_label(edge), event_end_at(edge)} do
      {nil, _} ->
        nil

      {start, %NaiveDateTime{} = ends} ->
        if NaiveDateTime.to_date(ends) == NaiveDateTime.to_date(edge.start_at),
          do: start <> " – " <> time_str(ends),
          else: start

      {start, _} ->
        start
    end
  end

  defp event_end_at(edge) do
    case Card.event_end_time(get_event_json(edge)) do
      %{local: %DateTime{} = dt} -> DateTime.to_naive(dt)
      _ -> nil
    end
  end

  defp wall_clock(iso) do
    case Card.event_time(iso) do
      %{local: %DateTime{} = dt} -> DateTime.to_naive(dt)
      _ -> nil
    end
  end

  defp time_str(%NaiveDateTime{} = dt),
    do: dt |> DateTime.from_naive!("Etc/UTC") |> DatesTimes.format(format: "h:mm a")
end
