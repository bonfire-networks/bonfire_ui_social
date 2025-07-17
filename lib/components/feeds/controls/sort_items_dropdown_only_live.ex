defmodule Bonfire.UI.Social.SortItemsDropdownOnlyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_filters, :any, default: nil
  prop event_target, :any, default: nil
end
