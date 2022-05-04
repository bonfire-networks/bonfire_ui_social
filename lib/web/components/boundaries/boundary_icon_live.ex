defmodule Bonfire.UI.Social.BoundaryIconLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object, :any

  def preload(list_of_assigns), do: Bonfire.Social.Objects.preload_boundaries(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
