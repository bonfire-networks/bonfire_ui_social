defmodule Bonfire.UI.Social.FeedControlsLiteLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
  prop reloading, :boolean, default: false

  @doc """
  Checks if a type is the only one included (tab is active)
  """
  def is_only_included?(type, field, feed_filters) do
    # Check if this type is in its field's include list
    include_list = e(feed_filters, field, [])
    is_in_list = type in include_list || to_string(type) in Enum.map(include_list, &to_string/1)

    # For true tab behavior, also check that no other filters are active
    total_filters =
      length(e(feed_filters, :object_types, [])) +
        length(e(feed_filters, :media_types, [])) +
        length(e(feed_filters, :activity_types, []))

    # This type is the only one selected if it's in its list AND total filters is 1
    is_in_list && total_filters == 1
  end

  @doc """
  Checks if no activity type filters are applied (default state)
  """
  def no_filters_applied?(feed_filters) do
    length(e(feed_filters, :object_types, [])) == 0 &&
      length(e(feed_filters, :media_types, [])) == 0 &&
      length(e(feed_filters, :activity_types, [])) == 0
  end

  @doc """
  Gets the button class based on whether this is the active tab
  """
  def get_button_class(type, field, feed_filters) do
    cond do
      # Special case: Posts button should be active when NO filters are applied
      type == :post && field == :object_types && no_filters_applied?(feed_filters) ->
        # Active tab state for default view
        "btn flex-1 w-full btn-primary"

      is_only_included?(type, field, feed_filters) ->
        # Active tab state
        "btn flex-1 w-full btn-primary"

      true ->
        # Inactive tab state
        "btn flex-1 w-full btn-ghost"
    end
  end

  @doc """
  Gets the toggle value for tab behavior.
  If this tab is already active, clicking it will reset to show all.
  If inactive, clicking it will make it the only active tab.
  """
  def get_tab_toggle_value(type, field, feed_filters) do
    cond do
      # Special case: Posts button when no filters applied should set the filter
      type == :post && field == :object_types && no_filters_applied?(feed_filters) ->
        # Set posts filter explicitly
        "true"

      is_only_included?(type, field, feed_filters) ->
        # Reset to default (show all)
        nil

      true ->
        # Set as only included type
        "true"
    end
  end
end
