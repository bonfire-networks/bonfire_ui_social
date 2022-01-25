defmodule Bonfire.UI.Social.LikeActionLive do
  use Bonfire.Web, :stateful_component

  prop object_id, :string
  prop like_count, :any, default: 0
  prop liked, :list
  prop my_like, :any
  prop label, :string

  def preload(list_of_assigns), do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)


end
