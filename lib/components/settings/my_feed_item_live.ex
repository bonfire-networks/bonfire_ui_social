defmodule Bonfire.UI.Social.Settings.MyFeedItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil
  prop key, :any
  prop label, :string, default: nil
  prop force_checked, :boolean, default: false
  prop force_unchecked, :boolean, default: false
  prop disabled, :boolean, default: false
end
