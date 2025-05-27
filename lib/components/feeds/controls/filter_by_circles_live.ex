defmodule Bonfire.UI.Social.FilterByCirclesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_filters, :map, required: true
  prop event_target, :any, required: true
  prop event_name, :string, default: "set_filter"
  prop container_id, :string, default: "open_circles"
  prop container_class, :string, default: "pb-0 flex pt-4 flex-col gap-2 hidden"
end
