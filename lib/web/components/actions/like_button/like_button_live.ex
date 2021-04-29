defmodule Bonfire.UI.Social.Actions.LikeButtonLive do
  use Bonfire.Web, :stateless_component

  prop direction, :string, required: true
  prop id, :string, required: true
  prop showing_within_thread, :boolean, default: false
  prop liker_count, :integer, default: 0
end
