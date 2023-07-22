defmodule Bonfire.UI.Social.ThreadControlsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.CommentLive

  prop event_target, :any, default: nil
  prop thread_mode, :any, default: nil
  prop showing_within, :atom, default: :thread
  prop sort_by, :any, default: nil
  prop sort_order, :any, default: false
  prop order_by, :any, default: :id
end
