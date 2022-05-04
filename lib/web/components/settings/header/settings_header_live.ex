
defmodule  Bonfire.UI.Social.SettingsViewLive.SettingsHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop settings_section_title, :string
  prop selected_tab, :string
  prop admin_tab, :string
end
