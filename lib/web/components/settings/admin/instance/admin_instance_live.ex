defmodule Bonfire.UI.Social.SettingsViewsLive.AdminInstanceLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop admin_tab, :string
  prop uploads, :any

end
