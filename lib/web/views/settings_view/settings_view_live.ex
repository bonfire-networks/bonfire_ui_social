
defmodule  Bonfire.UI.Social.SettingsViewLive do
  use Bonfire.Web, :live_component
  alias Bonfire.UI.Social.SettingsViewsLive.{
    SettingsNavigationLive,
    EditProfileLive,
    ExtensionsLive,
    EditAccountLive,
    AdminLive
  }
  # def update(assigns, socket) do


  #   {:ok, assign(socket, assigns
  #   |> assigns_merge(%{
  #       page: "Discussion",
  #       date_ago: date_from_now(assigns.object),
  #     })) }
  # end


end
