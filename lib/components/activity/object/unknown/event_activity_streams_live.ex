defmodule Bonfire.UI.Social.Activity.EventActivityStreamsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.DatesTimes
  alias Bonfire.Social.Events

  prop json, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop showing_within, :any, default: nil
  prop viewing_main_object, :boolean, default: nil

  # AS2 parsing is owned by the `Bonfire.Social.Events` context; these thin
  # delegates keep the template call-sites terse and the parsing single-sourced.
  defdelegate object_field(json, field), to: Events
  defdelegate poster_url(json), to: Events
  defdelegate source_host(url), to: Events
  defdelegate event_time(iso), to: Events, as: :parse_time
  defdelegate event_end_time(json), to: Events, as: :end_time

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
end
