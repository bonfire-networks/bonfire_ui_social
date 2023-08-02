defmodule Bonfire.UI.Social.FeedControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.CommentLive

  prop event_target, :any, default: nil
  # prop feed_id, :any, default: nil
  prop showing_within, :atom, default: :thread
  prop sort_by, :any, default: nil
  prop time_limit, :any, default: nil
  prop sort_order, :any, default: false
end
