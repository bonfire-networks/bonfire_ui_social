defmodule Bonfire.UI.Social.Components.Boost do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.BoostActionLive,
    height: "100px",
    direction: "vertical"


  def render(assigns) do
    ~F"""
    <BoostActionLive />
    """
  end
end
