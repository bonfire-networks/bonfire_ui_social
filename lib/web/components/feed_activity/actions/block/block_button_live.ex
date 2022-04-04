defmodule Bonfire.UI.Social.BlockButtonLive do
  use Bonfire.Web, :stateless_component
  # TODO: make stateful and preload block status?

  prop object, :any
  prop my_block, :any
  prop class, :string
  prop label, :string
  prop scope, :any # only used for unblock
  prop block_type, :any # only used for unblock

  # def preload(list_of_assigns), do: Bonfire.Boundaries.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
