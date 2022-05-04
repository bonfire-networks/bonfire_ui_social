defmodule Bonfire.UI.Social.SettingsViewsLive.ExtensionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop extensions, :list, default: []
  prop schemas, :any
  prop other_deps, :any
  prop get_link, :any
  prop settings_section_title, :string, default: "Bonfire extensions"
  prop selected_tab, :string
  prop ading_tab, :string

  def update(assigns, socket) do

    {:ok, assign(socket,
      assigns_merge(assigns, data())
    )}
  end

end
