defmodule Bonfire.UI.Social.SubscribeFeedLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop feed_name, :atom, default: nil
  prop params, :map, default: %{}
  prop as_icon, :boolean, default: false
end
