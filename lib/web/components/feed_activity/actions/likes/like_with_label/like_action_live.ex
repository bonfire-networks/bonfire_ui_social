defmodule Bonfire.UI.Social.LikeActionLive do
  use Bonfire.Web, :stateful_component
  prop object_id, :string
  prop like_count, :map
  prop liked, :list
  prop my_like, :any

  def preload(list_of_assigns), do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

end
