defmodule Bonfire.UI.Social.FeedPreferencesTest do
  use ExUnit.Case, async: true
  @moduletag :ui

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

    {:ok, navigated} = widget.update(%{initial | event_target: "#remote_feed", feed_name: :remote}, rerendered)
    assert navigated.assigns.feed_name == :remote
    assert navigated.assigns.feed_filters.sort_order == :desc
  end
end
