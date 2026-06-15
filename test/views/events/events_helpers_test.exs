defmodule Bonfire.UI.Social.EventsHelpersTest do
  @moduledoc "Unit tests for the pure data helpers behind the /events page (no DB)."
  use ExUnit.Case, async: true

  alias Bonfire.UI.Social.EventsLive
  alias Bonfire.UI.Social.EventHelpers
  alias Bonfire.UI.Social.EventCategories

  # Build a synthetic event "edge" as the LiveView holds it in memory.
  defp edge(start_at, json), do: %{event_json: json, start_at: start_at}

  defp event_json(opts) do
    %{"type" => "Event", "name" => opts[:name] || "An event"}
    |> maybe_put("startTime", opts[:start])
    |> maybe_put("endTime", opts[:end])
    |> maybe_put("id", opts[:id])
    |> maybe_put("category", opts[:category])
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  describe "event_categories/1 (FEP-8a8e)" do
    test "normalises a single category string to UPPER_SNAKE" do
      e = edge(~N[2026-06-20 18:00:00], event_json(category: "music"))
      assert EventHelpers.event_categories(e) == ["MUSIC"]
    end

    test "accepts an array of categories" do
      e = edge(~N[2026-06-20 18:00:00], event_json(category: ["MUSIC", "creative jam"]))
      assert EventHelpers.event_categories(e) == ["MUSIC", "CREATIVE_JAM"]
    end

    test "handles nested AS2 shape under object" do
      json = %{"object" => %{"type" => "Event", "category" => "PARTY"}}
      assert EventHelpers.event_categories(edge(~N[2026-06-20 18:00:00], json)) == ["PARTY"]
    end

    test "returns [] when no category" do
      assert EventHelpers.event_categories(edge(~N[2026-06-20 18:00:00], event_json([]))) == []
    end
  end

  describe "EventCategories" do
    test "known FEP categories get a localized label" do
      assert EventCategories.label("MUSIC") == "Music"
    end

    test "unknown categories fall back to a humanized label" do
      assert EventCategories.label("FOO_BAR") == "Foo Bar"
    end

    test "all/0 includes MEETING and every key has a label" do
      assert "MEETING" in EventCategories.all()
      for key <- EventCategories.all(), do: assert(is_binary(EventCategories.label(key)))
    end
  end

  describe "category_counts via category_count/2" do
    test "counts events per (normalized) category" do
      events = [
        edge(~N[2026-06-20 18:00:00], event_json(category: "music")),
        edge(~N[2026-06-21 18:00:00], event_json(category: ["MUSIC", "ARTS"]))
      ]

      counts = events |> Enum.flat_map(&EventHelpers.event_categories/1) |> Enum.frequencies()
      assert EventsLive.category_count(counts, "MUSIC") == 2
      assert EventsLive.category_count(counts, "ARTS") == 1
      assert EventsLive.category_count(counts, "SPORTS") == 0
    end

    test "categories/1 lists only populated categories, most-populated first" do
      counts = %{"SPORTS" => 3, "MUSIC" => 5}
      assert EventsLive.categories(counts) == ["MUSIC", "SPORTS"]
      assert EventsLive.categories(%{}) == []
    end
  end

  describe "filtered/2" do
    setup do
      today = Date.utc_today()

      events = [
        edge(NaiveDateTime.new!(Date.add(today, -3), ~T[10:00:00]), event_json(name: "past")),
        edge(
          NaiveDateTime.new!(Date.add(today, 2), ~T[10:00:00]),
          event_json(name: "soon", category: "music")
        ),
        edge(NaiveDateTime.new!(Date.add(today, 5), ~T[10:00:00]), event_json(name: "later"))
      ]

      {:ok, events: events, today: today}
    end

    test "with no filter shows only upcoming events", %{events: events} do
      assert events |> EventsLive.filtered(nil) |> names() == ["soon", "later"]
    end

    test "filters by category (normalized)", %{events: events} do
      assert events |> EventsLive.filtered("MUSIC") |> names() == ["soon"]
    end
  end

  describe "grouped/1 and day_label/1" do
    test "groups by day ascending" do
      d1 = ~N[2026-06-20 09:00:00]
      d1b = ~N[2026-06-20 18:00:00]
      d2 = ~N[2026-06-21 09:00:00]

      grouped =
        EventsLive.grouped([
          edge(d2, event_json(name: "b")),
          edge(d1, event_json(name: "a1")),
          edge(d1b, event_json(name: "a2"))
        ])

      assert [{~D[2026-06-20], two}, {~D[2026-06-21], one}] = grouped
      assert length(two) == 2
      assert length(one) == 1
    end

    test "day_label/1 uses relative labels around today" do
      today = Date.utc_today()
      assert EventsLive.day_label(today) == "Today"
      assert EventsLive.day_label(Date.add(today, 1)) == "Tomorrow"
      assert EventsLive.day_label(Date.add(today, -1)) == "Yesterday"
      assert is_binary(EventsLive.day_label(Date.add(today, 10)))
    end
  end

  defp names(events), do: Enum.map(events, & &1.event_json["name"])
end
