defmodule Bonfire.UI.Social.Activity.BoostActionLive do
  use Bonfire.Web, :stateful_component

  prop object_id, :string
  prop my_boost, :any
  prop boost_count, :any

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
