defmodule Bonfire.UI.Social.SettingsViewsLive.ExtensionsLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Extensions
  
  prop extensions, :list, default: []
  prop schemas, :any
  prop other_deps, :any
  prop get_link, :any
  prop settings_section_title, :string, default: "Bonfire extensions"
  prop settings_section_description, :string, default: "These are the extensions installed on this instance."

  def update(assigns, socket) do

    {:ok, assign(socket,
      assigns_merge(assigns, data())
    )}
  end

end
