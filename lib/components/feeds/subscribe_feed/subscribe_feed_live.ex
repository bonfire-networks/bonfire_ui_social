defmodule Bonfire.UI.Social.SubscribeFeedLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop feed_name, :any, default: nil
  prop params, :map, default: %{}
  prop as_icon, :boolean, default: false
  prop icon_button_class, :css_class, default: "btn btn-sm btn-square rounded-md"
  prop icon_class, :css_class, default: nil
  prop parent_id, :any, default: nil
end
