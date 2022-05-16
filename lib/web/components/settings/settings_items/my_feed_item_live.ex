defmodule Bonfire.UI.Social.SettingsViewsLive.MyFeedItemLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop key, :any
  prop label, :string
  prop force_checked, :boolean, default: false
  prop force_unchecked, :boolean, default: false
  prop disabled, :boolean, default: false
end
