defmodule Bonfire.UI.Social.FeedControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.CommentLive

  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
  prop reloading, :boolean, default: false
  # prop sort_by, :any, default: nil
  # prop time_limit, :any, default: nil
  # prop sort_order, :any, default: false
end
