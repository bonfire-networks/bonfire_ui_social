defmodule Bonfire.UI.Social.PrivateLive do
  use Bonfire.Web, :stateless_component

  prop feed, :list
  prop users, :list
  prop tab_id, :string
  prop to_circles, :list
  
  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
