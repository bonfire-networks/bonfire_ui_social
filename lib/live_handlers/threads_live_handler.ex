defmodule Bonfire.Social.Threads.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  def handle_info(:load_thread, socket) do
    debug("async loading")
    {:noreply, load_thread(socket)}
  end

  def handle_info({:new_reply, {thread_id, data}}, socket) do
    debug("received :new_reply")

    # id = e(data, :object, :id, nil) || e(data, :id, nil)
    # permitted? = id && Bonfire.Common.Pointers.exists?([id: id], current_user: current_user(socket)) |> debug("double check boundary upon receiving a LivePush")

    # if permitted?, do: # Note: now checking permission in ThreadLive
    maybe_send_update(Bonfire.UI.Social.ThreadLive, thread_id, new_reply: data)

    {:noreply, socket}
  end

  def thread_init(socket) do
    # debug(assigns, "thread assigns")
    current_user = current_user(socket)
    object = e(socket.assigns, :object, nil) || e(socket.assigns, :activity, :object)

    thread_id =
      e(socket.assigns, :thread_id, nil) ||
        e(socket.assigns, :activity, :replied, :thread_id, nil) ||
        e(object, :replied, :thread_id, nil)

    socket
    |> maybe_subscribe(thread_id)
    |> assign(
      # activity: activity,
      # object: object,
      # reply_to_id: e(object, :id, thread_id),
      # TODO: change for thread forking?
      thread_id: thread_id,
      current_user: current_user,
      page: "thread"
      # participants: participants
    )

    # |> IO.inspect
  end

  def load_thread_maybe_async(%Phoenix.LiveView.Socket{} = socket) do
    socket_connected = connected?(socket)

    if (socket_connected || current_user(socket)) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load async")
        pid = self()

        async_task(fn ->
          thread_id = e(socket.assigns, :thread_id, e(socket.assigns, :object, :id, nil))
          # Query comments asynchronously
          maybe_send_update(
            pid,
            Bonfire.UI.Social.ThreadLive,
            e(socket.assigns, :id, thread_id),
            load_thread_assigns(socket) ++ [loaded_async: true]
          )
        end)
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      socket
      |> assign(loading: true)
    else
      debug("socket not connected or not logged in, just load feed")
      load_thread(socket)
    end
  end

  def load_thread_maybe_async(_thread_id, _assigns, socket_or_opts) do
    # debug(e(socket_or_opts, :assigns, nil), "not socket")
    load_thread(socket_or_opts)
  end

  def load_thread(socket) do
    with assigns when is_list(assigns) <- load_thread_assigns(socket) do
      socket
      |> assign(assigns)
    else
      e ->
        error(e)

        socket
        |> assign_flash(:error, "Could not load comments")
        |> assign(loading: false)
    end
  end

  def load_thread_assigns(socket) do
    debug("load comments")
    thread_id = e(socket.assigns, :thread_id, e(socket.assigns, :object, :id, nil))

    if thread_id do
      debug("loading by thread_id")
      # debug(assigns)
      current_user = current_user(socket)

      max_depth = Config.get(:thread_default_max_depth, 3)

      with %{edges: replies, page_info: page_info} <-
             Bonfire.Social.Threads.list_replies(thread_id,
               current_user: current_user,
               after: e(socket.assigns, :after, nil),
               max_depth: max_depth,
               thread_mode: e(socket.assigns, :thread_mode, nil),
               reverse_order: e(socket.assigns, :reverse_order, nil),
               showing_within: e(socket.assigns, :showing_within, nil)
             ) do
        # debug(replies, "queried replies")
        debug(thread_id, "loaded #{length(replies)} comments for thread")

        threaded_replies =
          if e(socket.assigns, :thread_mode, nil) != :flat and is_list(replies) and
               length(replies) > 0,
             do: Bonfire.Social.Threads.arrange_replies_tree(replies)

        debug(threaded_replies, "threaded_replies")

        [
          loading: false,
          replies: replies,
          threaded_replies: threaded_replies,
          page_info: page_info,
          thread_id: thread_id
        ]
      end
    end
  end

  def maybe_subscribe(socket, thread_id) do
    if thread_id && !e(socket.assigns, :pubsub_subscribed, nil) do
      debug(thread_id, "subscribing to live thread updates")
      PubSub.subscribe(thread_id, socket)

      socket
      |> assign(:pubsub_subscribed, true)
    else
      debug(
        thread_id,
        "no thread_id known, or already subscribed not subscribing to live thread updates"
      )

      socket
    end
  end
end
