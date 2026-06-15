defmodule Bonfire.UI.Social.Activity.EventActivityStreamsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.DatesTimes

  prop json, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop showing_within, :any, default: nil
  prop viewing_main_object, :boolean, default: nil

  defp object_field(json, field) do
    e(json, "object", field, nil) || e(json, field, nil)
  end

  @doc "Returns the URL of the first image attachment to use as the event poster, or `nil`."
  def poster_url(json) do
    case object_field(json, "attachment") do
      attachments when is_list(attachments) ->
        attachments
        |> Enum.find(fn a ->
          e(a, "type", nil) == "Document" and
            String.starts_with?(to_string(e(a, "mediaType", "")), "image/")
        end)
        |> case do
          nil ->
            nil

          attachment ->
            e(attachment, "url", 0, "href", nil) || e(attachment, "url", "href", nil) ||
              e(attachment, "url", nil)
        end

      _ ->
        nil
    end
  end

  @doc """
  Parse an ISO8601 event time into the data the card needs.

  Restores the event's *original* local wall-clock time (federated events carry
  their own timezone), so a 17:00 event reads as 17:00 regardless of the viewer's
  zone, and keeps the raw ISO string for a machine-readable `<time datetime=…>`.

  Returns `%{iso: binary, local: DateTime.t(), offset: integer}` or `nil`.
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
  The end time of an event, or `nil` when there's no end or it's marked hidden
  (`displayEndTime == "false"`).
  """
  def event_end_time(json) do
    if object_field(json, "displayEndTime") != "false" do
      event_time(object_field(json, "endTime"))
    end
  end

  @doc """
  A concise, human-readable date/time range.

  Collapses redundancy: the date appears once when start and end share a day, and
  the timezone is shown once at the end. Examples:

      "Mon, Jun 8, 2026 · 1:00 PM – 3:00 PM (GMT+2)"   # same day
      "Mon, Jun 8, 2026 · 1:00 PM → Tue, Jun 9, 2026 · 9:00 AM (GMT+2)"  # multi-day
      "Mon, Jun 8, 2026 · 1:00 PM (GMT+2)"             # no end time
  """
  def format_range(start_t, end_t \\ nil)

  def format_range(%{local: s} = start_t, nil) do
    "#{date_at(s)} (#{gmt_label(start_t.offset)})"
  end

  def format_range(%{local: s} = start_t, %{local: e}) do
    body =
      if same_day?(s, e) do
        "#{date_at(s)} – #{time_only(e)}"
      else
        "#{date_at(s)} → #{date_at(e)}"
      end

    "#{body} (#{gmt_label(start_t.offset)})"
  end

  def format_range(_, _), do: nil

  defp date_at(dt), do: "#{DatesTimes.format(dt, format: "EEE, MMM d, y")} · #{time_only(dt)}"

  defp time_only(dt), do: DatesTimes.format(dt, format: "h:mm a")

  defp same_day?(a, b), do: DateTime.to_date(a) == DateTime.to_date(b)

  defp gmt_label(0), do: "GMT"

  defp gmt_label(offset) do
    sign = if offset < 0, do: "-", else: "+"
    abs_offset = abs(offset)
    hours = div(abs_offset, 3600)
    minutes = rem(div(abs_offset, 60), 60)

    if minutes == 0 do
      "GMT#{sign}#{hours}"
    else
      "GMT#{sign}#{hours}:#{minutes |> Integer.to_string() |> String.pad_leading(2, "0")}"
    end
  end

  @doc """
  Short calendar-chip parts (locale-aware): `%{weekday: "Mon", day: "8", month: "Jun"}`.
  """
  def chip_parts(%{local: local}) do
    %{
      weekday: DatesTimes.format(local, format: "EEE"),
      day: DatesTimes.format(local, format: "d"),
      month: DatesTimes.format(local, format: "MMM")
    }
  end

  def chip_parts(_), do: nil

  @doc """
  Host of the source URL, for the read-only "View on …" link (e.g. `"gancio.cisti.org"`).
  """
  def source_host(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  def source_host(_), do: nil
end
