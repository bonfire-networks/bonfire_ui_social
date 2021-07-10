defmodule Bonfire.UI.Social.Activity.BoostsLive do
  use Bonfire.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string
  prop my_boost, :any
  prop boost_count, :any
end
