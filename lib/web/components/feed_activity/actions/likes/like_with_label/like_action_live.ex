defmodule Bonfire.UI.Social.LikeActionLive do
<<<<<<< HEAD:lib/web/components/feed_activity/actions/likes/like_with_label/like_action_live.ex
  use Bonfire.Web, :stateless_component
  prop object_id, :string
  prop my_like, :map
  prop like_count, :map
=======
  use Bonfire.Web, :stateful_component

  prop object_id, :string
  prop liked, :list
  prop my_like, :any

  def preload(list_of_assigns), do: Bonfire.Social.Likes.LiveHandler.preload(list_of_assigns)

>>>>>>> 1221fb1 (stateful likes):lib/web/components/likes/like_with_label/like_action_live.ex
end
