defmodule Bonfire.UI.Social.Components.Header.HeaderGuest do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.HeaderGuestLive,
    height: "100px",
    direction: "vertical"


  def render(assigns) do
    ~F"""
    <HeaderGuestLive />
    """
  end
end
