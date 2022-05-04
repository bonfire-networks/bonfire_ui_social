defmodule Bonfire.UI.Social.BlockMenuButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop peered, :any

  def peered(assigns) do
    e(assigns, :peered, nil) || e(assigns, :object, :peered, nil) || e(assigns, :object, :character, :peered, nil)
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
