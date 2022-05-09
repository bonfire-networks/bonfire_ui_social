defmodule Bonfire.UI.Social.SettingsViewsLive.ExtensionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop data, :list, default: []
  prop feature_extensions, :list, default: []
  prop ui, :list, default: []
  prop schemas, :list, default: []
  prop ecosystem_libs, :list, default: []
  prop other_deps, :list, default: []
  prop get_link, :any
  prop settings_section_title, :string, default: "Bonfire extensions"
  prop selected_tab, :string
  prop ading_tab, :string

end
