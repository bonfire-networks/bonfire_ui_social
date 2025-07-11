defmodule Bonfire.UI.Social.FilterByCirclesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_filters, :any, default: nil
  prop event_target, :any, required: true
  prop event_name, :string, default: "set_filter"
  prop container_id, :string, default: "open_circles"
  prop container_class, :string, default: "pb-0 flex flex-col gap-2"
end
