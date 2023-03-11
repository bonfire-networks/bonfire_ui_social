defmodule Bonfire.UI.Social.ThreadLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Untangle
  # alias Bonfire.Fake
  # alias Bonfire.UI.Me.LivePlugs
  # alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.CreateUserLive
  alias Bonfire.Social.Threads.LiveHandler
  # import Bonfire.Me.Integration

  prop replies, :any, default: nil
  prop threaded_replies, :any, default: nil
  prop page_info, :any, default: nil
  prop activity, :any, default: nil
  prop object, :any, default: nil
  prop reply_to_id, :any, default: nil
  # prop thread_id, :any, default: nil
  prop page, :any, default: "thread"
  prop feed_id, :any, default: nil
  prop create_object_type, :any, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop url, :string, default: nil
  prop smart_input_opts, :map, default: %{}
  prop thread_mode, :any, default: nil
  prop reverse_order, :any, default: nil
  prop showing_within, :atom, default: :thread
  prop loading, :boolean, default: false

  def update(%{replies: replies, page_info: page_info, loaded_async: true} = assigns, socket)
      when is_list(replies) and is_map(page_info) do
    debug("showing async-loaded replies")

    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(%{replies: replies, page_info: page_info} = assigns, socket)
      when is_list(replies) and is_map(page_info) do
    debug("showing preloaded replies")

    {:ok,
     socket
     |> assign(assigns)
     |> LiveHandler.thread_init()}
  end

  def update(%{new_reply: new_reply}, socket) when is_map(new_reply) do
    debug("adding new reply")

    thread_id = e(socket.assigns, :thread_id, nil)

    if e(socket.assigns, :thread_mode, nil) == :flat do
      debug("flat thread")

      object_id =
        e(new_reply, :object, :id, nil) || e(new_reply, :activity, :object, :id, nil) ||
          e(new_reply, :id, nil)

      # Note: doing this hear temporarily while not using pushed comment for nested threads
      permitted? =
        object_id &&
          Bonfire.Common.Pointers.exists?([id: object_id], current_user: current_user(socket))
          |> debug("double check boundary upon receiving a LivePush")

      if permitted? do
        replies = e(socket.assigns, :replies, []) ++ [new_reply]

        {:ok,
         socket
         |> assign(replies: replies)}
      else
        {:ok, socket}
      end
    else
      debug("nested thread")

      # FIXME: we should inject the reply rather than reloading

      # cannot redirect in `update` so we trigger a reload of the thread instead
      update(%{}, socket)

      # temporary
      # activity_id = e(new_reply, :activity, :id, nil) || e(new_reply, :id, nil)

      # thread_url =
      #   if is_struct(e(socket.assigns, :object, nil)) do
      #     path(e(socket.assigns, :object, nil))
      #   else
      # "/discussion/#{thread_id}"
      #   end

      # permalink = "#{thread_url}#activity-#{activity_id}"

      # {
      #   :ok,
      #   socket
      #   |> patch_to(permalink)
      #   # |> LiveHandler.load_thread()
      # }

      # FIMXE: nesting gets messed up when replying to a reply that was added to the thread this way
      # path = (
      #   e(new_reply, :object, :replied, :path, nil)
      #   || e(new_reply, :replied, :path, nil)
      #   || e(new_reply, :activity, :replied, :path, [])
      # )
      # |> debug("path")

      # replies = [
      #   new_reply
      #   |> Map.put(:path, path)
      # ] ++ e(socket.assigns, :replies, [])

      # {:ok, socket
      #   |> assign(
      #     replies: replies,
      #     threaded_replies: Bonfire.Social.Threads.arrange_replies_tree(replies) |> debug()
      #   )
      # }
    end
  end

  def update(%{__context__: %{new_reply: new_reply}} = assigns, socket) do
    # debug(context_reply: new_reply)
    update(Map.merge(assigns, %{new_reply: new_reply}), socket)
  end

  def update(assigns, socket) do
    debug("Load comments")
    # debug(assigns, "Thread: assigns")

    {:ok,
     socket
     |> assign(assigns)
     |> LiveHandler.thread_init()
     |> LiveHandler.load_thread_maybe_async()}
  end

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

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
