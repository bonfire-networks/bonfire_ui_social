defmodule Bonfire.UI.Social.FollowButtonLive do
  use Bonfire.Web, :stateful_component

  prop object, :any
  prop class, :string
  prop icon_class, :string
  prop label, :string
  prop my_follow, :boolean

  def preload(list_of_assigns), do: Bonfire.Social.Follows.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
