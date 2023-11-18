defmodule Bonfire.UI.Social.Settings.MyFeedItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil
  prop key, :any
  prop label, :string, default: nil
  prop force_checked, :any, default: nil
  prop disabled, :boolean, default: false
end
