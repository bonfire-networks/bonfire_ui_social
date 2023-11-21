defmodule Bonfire.UI.Social.BoostActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :any
  prop object_type, :any
  prop object_boundary, :any, default: nil
  prop boost_count, :any
  prop showing_within, :atom
  prop my_boost, :any, default: nil

  def update_many(assigns_sockets),
    do: Bonfire.Social.Boosts.LiveHandler.update_many(assigns_sockets, caller_module: __MODULE__)

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
