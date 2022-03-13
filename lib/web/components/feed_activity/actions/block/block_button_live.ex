defmodule Bonfire.UI.Social.BlockButtonLive do
  use Bonfire.Web, :stateless_component
  # TODO: make stateful and preload block status?

  prop object, :any
  prop my_block, :any
  prop class, :string
  prop label, :string
  prop scope, :string
  prop block_type, :atom

  # def preload(list_of_assigns), do: Bonfire.Boundaries.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
