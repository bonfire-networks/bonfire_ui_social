defmodule Bonfire.UI.Social.Settings.MyFeedItemsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string
  prop scope, :any, default: nil
  prop feed_name, :atom, default: nil
end
