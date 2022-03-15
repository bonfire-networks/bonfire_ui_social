
defmodule  Bonfire.UI.Social.SettingsViewLive.SettingsHeaderLive do
  use Bonfire.Web, :stateless_component
  prop settings_section_title, :string
  prop selected_tab, :string
  prop admin_tab, :string
end
