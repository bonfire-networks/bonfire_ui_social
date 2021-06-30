defmodule Bonfire.UI.Social.LikeActionLive do
  use Bonfire.Web, :stateless_component
  prop object_id, :string
  prop my_like, :map
  prop like_count, :map
end
