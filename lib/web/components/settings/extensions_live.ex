defmodule Bonfire.UI.Social.SettingsViewsLive.ExtensionsLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Extensions
  
  prop extensions, :any
  prop schemas, :any
  prop other_deps, :any
  prop get_link, :any

  def update(assigns, socket) do

    {:ok, assign(socket,
      assigns_merge(data(),
        settings_section_title: "Bonfire Extensions",
        settings_section_description: "These are the extensions currently installed on this instance."
      )) }
  end

end
