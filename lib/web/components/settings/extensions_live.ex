defmodule Bonfire.UI.Social.SettingsViewsLive.ExtensionsLive do
  use Bonfire.Web, :live_component
  import Bonfire.Common.Extensions

  def update(assigns, socket) do

    {:ok, assign(socket,
      assigns_merge(data(),
        settings_section_title: "Bonfire Extensions",
        settings_section_description: "These are the extensions currently installed on this instance."
      )) }
  end

end
