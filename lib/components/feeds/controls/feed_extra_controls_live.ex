defmodule Bonfire.UI.Social.FeedExtraControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.CommentLive

  prop event_name, :any, default: "set_filter"
  prop event_target, :any, default: nil
  # prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop hide_filters, :list, default: []
  prop feed_filters, :any, default: nil
  # prop sort_by, :any, default: nil
  # prop time_limit, :any, default: nil
  # prop sort_order, :any, default: false

  @doc """
  Bulk version that processes multiple values at once.
  Returns a map of value => result for efficient lookups.

  # TODO: use this once when rendering the component
  """
  def check_throuples(values, include, exclude) when is_list(values) do
    activity_set = MapSet.new(include)
    exclude_set = MapSet.new(exclude)

    values
    |> Stream.map(fn value ->
      {value, Bonfire.UI.Social.ToggleTypeLive.check_throuple(value, activity_set, exclude_set)}
    end)
    |> Map.new()
  end

  @doc """
  Checks if current user's activities are excluded from the feed.
  Returns true if user is in exclude_subjects list, false otherwise.
  """
  def user_activities_excluded?(feed_filters, context) do
    case current_user_id(context) do
      nil ->
        false

      user_id ->
        exclude_subjects = e(feed_filters, :exclude_subjects, [])
        user_id in exclude_subjects or to_string(user_id) in exclude_subjects
    end
  end

  @doc """
  Checks if replies are excluded from the feed.
  Returns true if :reply is in exclude_activity_types list, false otherwise.
  """
  def replies_excluded?(feed_filters) do
    exclude_activity_types = e(feed_filters, :exclude_activity_types, [])

    case exclude_activity_types do
      # Handle when it's explicitly false
      false ->
        false

      types when is_list(types) ->
        :reply in types or "reply" in types

      _ ->
        false
    end
  end

  @doc """
  Checks if boosts are excluded from the feed.
  Returns true if :boost is in exclude_activity_types list, false otherwise.
  """
  def boosts_excluded?(feed_filters) do
    exclude_activity_types = e(feed_filters, :exclude_activity_types, [])

    case exclude_activity_types do
      # Handle when it's explicitly false
      false ->
        false

      types when is_list(types) ->
        :boost in types or "boost" in types

      _ ->
        false
    end
  end

  @doc """
  Gets preset origin information for the feed.
  Returns a map with preset_has_fixed_origin and preset_origin values.
  """
  def get_preset_origin_info(feed_filters, context) do
    feed_name = e(feed_filters, :feed_name, nil)

    case Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, context: context) do
      {:ok, %{filters: %{origin: preset_origin}}} when not is_nil(preset_origin) ->
        %{
          preset_has_fixed_origin: true,
          preset_origin: preset_origin
        }

      _ ->
        %{
          preset_has_fixed_origin: false,
          preset_origin: nil
        }
    end
  end
end
