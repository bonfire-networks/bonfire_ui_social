defmodule Bonfire.UI.Social.LikeActionLive do
  use Bonfire.Web, :stateful_component

  prop object, :map
  prop like_count, :any, default: 0
  prop label, :string

  def preload(list_of_assigns), do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)


end
