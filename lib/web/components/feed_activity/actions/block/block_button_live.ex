defmodule Bonfire.UI.Social.BlockButtonLive do
  use Bonfire.Web, :stateful_component

  prop object, :any
  prop class, :string
  prop label, :string
  prop scope, :string

  # def preload(list_of_assigns), do: Bonfire.Me.Boundaries.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
