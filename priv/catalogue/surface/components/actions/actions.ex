defmodule Bonfire.UI.Social.Components.Actions do
  use Surface.Catalogue.Example,
    catalogue: Bonfire.UI.Social.Components.Catalogue,
    subject: Bonfire.UI.Social.Activity.ActionsLive,
    height: "100px",
    direction: "vertical"


  def render(assigns) do
    ~F"""
    <ActionsLive />
    """
  end
end
