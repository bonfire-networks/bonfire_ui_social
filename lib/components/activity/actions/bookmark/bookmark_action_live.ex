defmodule Bonfire.UI.Social.BookmarkActionLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :any
  prop object_type, :any
  prop my_bookmark, :boolean, default: false
  # prop label, :string, default: nil
  # prop showing_within, :atom, default: nil

  # def update_many(assigns_sockets),
  #   do: Bonfire.Social.Bookmarks.LiveHandler.update_many(assigns_sockets, caller_module: __MODULE__)

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
