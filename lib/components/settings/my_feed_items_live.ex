defmodule Bonfire.UI.Social.Settings.MyFeedItemsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string
  prop scope, :atom, default: nil

end
