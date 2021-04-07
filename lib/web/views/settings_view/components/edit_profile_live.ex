defmodule Bonfire.UI.Social.SettingsViewsLive.EditProfileLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      settings_section_title: "Profile",
      settings_section_description: "This information will be displayed publicly so be careful what you share."
      })) }
  end

end
