defmodule Bonfire.Social.Threads.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_info(:load_thread, socket) do
    debug("async loading")
    {:noreply, load_thread(socket)}
  end

  def thread_init(socket) do
    # debug(assigns, "thread assigns")
    current_user = current_user(socket)
    object = e(socket.assigns, :object, nil) || e(socket.assigns, :activity, :object)
    thread_id = e(socket.assigns, :thread_id, nil) || e(socket.assigns, :activity, :replied, :thread_id, nil) || e(object, :replied, :thread_id, nil)

    maybe_subscribe(thread_id, socket)

    socket
    |> assign(
      # activity: activity,
      # object: object,
      reply_to_id: e(object, :id, thread_id),
      thread_id: thread_id, # TODO: change for thread forking?
      current_user: current_user,
      page: "thread",
      # participants: participants
    ) #|> IO.inspect
  end

  def load_thread_maybe_async(%Phoenix.LiveView.Socket{} = socket) do
    if connected?(socket) and Config.get(:env) != :test do
      # dump(socket.assigns, "connected")

      # send(self(), {Bonfire.Social.Threads.LiveHandler, :load_thread})
      pid = self()
      Task.async(fn ->
        thread_id = e(socket.assigns, :thread_id, e(socket.assigns, :object, :id, nil))
        # Query comments asynchronously
        send_update(pid, Bonfire.UI.Social.ThreadLive, load_thread_assigns(socket) ++ [id: e(socket.assigns, :id, thread_id)])
      end)

      socket
      |> assign(
        loading: true
      )

    else
      # dump(socket.assigns, "disconnected")
      # for dead mounts
      load_thread(socket)
    end
  end
  def load_thread_maybe_async(thread_id, assigns, socket_or_opts) do
    # dump(e(socket_or_opts, :assigns, nil), "not socket")
    load_thread(socket_or_opts)
  end

  def load_thread(socket) do
    with assigns when is_list(assigns) <- load_thread_assigns(socket) do

      socket
      |> assign(assigns)

    else e ->
      error(e)

      socket
      |> assign_flash(:error, "Could not load comments")
      |> assign(
        loading: false
      )
    end
  end

  def load_thread_assigns(socket) do
    debug("load comments")
    thread_id = e(socket.assigns, :thread_id, e(socket.assigns, :object, :id, nil))

    if thread_id do
      info("loading by thread_id")
      # debug(assigns)
      current_user = current_user(socket)

      max_depth =  Config.get(:thread_default_max_depth, 3)

      with %{edges: replies, page_info: page_info} <- Bonfire.Social.Threads.list_replies(thread_id,
        current_user: current_user,
        after: e(socket.assigns, :after, nil),
        max_depth: max_depth,
        thread_mode: e(socket.assigns, :thread_mode, nil),
        reverse_order: e(socket.assigns, :reverse_order, nil),
        showing_within: e(socket.assigns, :showing_within, nil)
      ) do
        # debug(replies, "queried replies")
        # debug(thread_id, "loaded #{length(replies)} comments for thread")

        threaded_replies = if e(socket.assigns, :thread_mode, nil) !=:flat and is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies)
        # debug(threaded_replies, "threaded_replies")

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

  def maybe_subscribe(thread_id, socket) do
    if thread_id do
      pubsub_subscribe(thread_id, socket)
    else
      debug("no thread_id known, not subscribing to live updates")
    end
  end

end
