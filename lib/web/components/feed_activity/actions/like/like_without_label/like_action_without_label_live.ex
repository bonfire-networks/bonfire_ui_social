defmodule Bonfire.UI.Social.LikeActionWithoutLabelLive do
  use Bonfire.Web, :stateless_component

  prop object_id, :string
  prop like_count, :any
  prop liked, :list
  prop my_like, :any

  # def preload(list_of_assigns), do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

end
