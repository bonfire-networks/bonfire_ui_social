defmodule Bonfire.UI.Social.LikeActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :any
  prop object_type, :any
  prop object_boundary, :any, default: nil
  prop like_count, :any, default: 0
  # prop label, :string, default: nil
  # prop showing_within, :atom, default: nil
  prop my_like, :any, default: nil

  def update_many(assigns_sockets),
    do: Bonfire.Social.Likes.LiveHandler.update_many(assigns_sockets, caller_module: __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
