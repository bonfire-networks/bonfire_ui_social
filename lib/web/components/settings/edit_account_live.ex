defmodule Bonfire.UI.Social.SettingsViewsLive.EditAccountLive do
  use Bonfire.Web, :stateless_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      settings_section_title: "Account",
      settings_section_description: "This information will be displayed publicly so be careful what you share."
      })) }
  end


end
