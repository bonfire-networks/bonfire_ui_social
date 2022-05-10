defmodule Bonfire.UI.Social.SettingsViewsLive.InstanceInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop admin_tab, :string
  prop uploads, :any
end
