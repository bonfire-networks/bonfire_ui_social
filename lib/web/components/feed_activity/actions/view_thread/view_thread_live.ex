defmodule Bonfire.UI.Social.Activity.ViewThreadLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string
  prop permalink, :string
  prop replied, :any

end
