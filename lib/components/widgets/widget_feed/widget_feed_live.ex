defmodule Bonfire.UI.Social.WidgetFeedLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  prop event_target, :any, default: nil
  # prop feed_id, :any, default: nil
  prop feed_name, :atom, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
end
