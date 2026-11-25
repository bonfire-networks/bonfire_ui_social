defmodule Bonfire.UI.Social.FeedPreferencesTest do
  use ExUnit.Case, async: true
  @moduletag :ui
  doctest Bonfire.UI.Social.WidgetCustomizeFeedLive,
    only: [order_filters: 2, preferences_changed?: 2]

  doctest Bonfire.Social.Feeds.LiveHandler, only: [override_filters: 3]

  @widget Bonfire.UI.Social.WidgetCustomizeFeedLive

  defp values(filters), do: Enum.map(@widget.order_options(filters), &elem(&1, 0))

  test "Soonest first is offered with a Happening filter or a feed of events only, as Most recent first for the past" do
    assert {"starts_at", "Most recent first"} in @widget.order_options(%{time_span: :past})
    assert {"starts_at", "Soonest first"} in @widget.order_options(%{time_span: :upcoming})

    refute "starts_at" in values(%{})
    refute "starts_at" in values(nil)
    refute "starts_at" in values(%{object_types: ["Post", "Event"]})
    assert "starts_at" in values(%{time_span: :upcoming})
    assert "starts_at" in values(%{happening_from: ~U[2030-01-01 00:00:00Z]})
    assert "starts_at" in values(%{object_types: ["Event"]})
  end

  # the popularity score can't be indexed, so only media feeds (which page their ranked aggregate) offer it; activity feeds get it through the cached `trending` preset
  test "Popularity is offered on media feeds only" do
    assert "popularity_score" in values(%{media_types: ["image"]})
    assert "popularity_score" in values(%{media_types: [:link]})
    refute "popularity_score" in values(%{})
    refute "popularity_score" in values(nil)
    refute "popularity_score" in values(%{media_types: []})
  end

  test "ordering by the start date is earliest first, latest first for the past" do
    assert @widget.order_filters("starts_at", %{}) == %{sort_by: :starts_at, sort_order: :asc}

    assert @widget.order_filters("starts_at", %{time_span: :past}) ==
             %{sort_by: :starts_at, sort_order: :desc}

    assert @widget.current_order(%{sort_by: :starts_at, sort_order: :asc}) == "starts_at"
  end

  test "ranking preserves an explicitly selected time range, including All time" do
    for order <- ["reply_count", "boost_count", "like_count", "popularity_score", "latest_reply"],
        time_limit <- [0, "0", 30] do
      filters = %{time_limit: time_limit, exclude_activity_types: [:reply]}
      changes = Bonfire.UI.Social.WidgetCustomizeFeedLive.order_filters(order, filters)
      refute Map.has_key?(changes, :time_limit)
      assert Map.merge(filters, changes).time_limit == time_limit
    end
  end

  test "live preferences survive parent renders and reset for a new page selection" do
    widget = Bonfire.UI.Social.WidgetCustomizeFeedLive

    initial = %{
      event_target: "#local_feed",
      feed_name: :local,
      feed_filters: %{sort_order: :desc}
    }

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, initial_preferences: nil}}

    {:ok, mounted} = widget.update(initial, socket)
    {:ok, edited} = widget.update(%{preferences: %{feed_filters: %{sort_order: :asc}}}, mounted)
    {:ok, rerendered} = widget.update(initial, edited)
    assert rerendered.assigns.feed_filters.sort_order == :asc

    {:ok, navigated} =
      widget.update(%{initial | event_target: "#remote_feed", feed_name: :remote}, rerendered)

    assert navigated.assigns.feed_name == :remote
    assert navigated.assigns.feed_filters.sort_order == :desc
  end
end
