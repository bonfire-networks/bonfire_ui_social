defmodule Bonfire.UI.Social.Settings.ReactionsSortItemsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string
  prop scope, :any, default: nil
  prop feed_name, :atom, default: nil
  prop event_name, :any, default: nil
  prop event_target, :any, default: nil
  prop compact, :boolean, default: false
end
