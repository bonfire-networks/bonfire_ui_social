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
end
