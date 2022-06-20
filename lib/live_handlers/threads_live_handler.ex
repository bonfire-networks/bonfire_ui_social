defmodule Bonfire.Social.Threads.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_info(:load_thread, socket) do
    {:noreply, socket
      |> assign(load_thread_assigns(socket))
    }
  end

  def initial_thread_assigns(assigns, socket) do

    # debug(assigns, "thread assigns")
    current_user = current_user(assigns) || current_user(socket)
    activity = e(assigns, :activity, nil) #|> IO.inspect
    object = e(assigns, :object, e(activity, :object)) #|> IO.inspect
    thread_id = e(activity, :replied, :thread_id, nil) || e(assigns, :thread_id, nil)

    maybe_subscribe(thread_id, socket)

    assigns
    |> assigns_merge(
      loading: true,
      # thread_id: thread_id,
      activity: activity,
      object: object,
      reply_to_id: e(activity, :object, :id, thread_id),
      thread_id: thread_id, # TODO: change for thread forking?
      current_user: current_user,
      page: "thread",
      # participants: participants
    ) #|> IO.inspect
  end

  def thread_assigns_or_load_async(assigns, %Phoenix.LiveView.Socket{} = socket) do
    if connected?(socket) and Config.get(:env) != :test do
      # dump(socket.assigns, "connected")
      send(self(), {Bonfire.Social.Threads.LiveHandler, :load_thread})
      assigns
    else
      # dump(socket.assigns, "disconnected")
      # for dead mounts
      load_thread_assigns(assigns, socket)
    end
  end
  def thread_assigns_or_load_async(thread_id, assigns, socket_or_opts) do
    # dump(e(socket_or_opts, :assigns, nil), "not socket")
    load_thread_assigns(assigns, socket_or_opts)
  end

  def load_thread_assigns(assigns \\ nil, socket) do
    debug("load comments")
    assigns = assigns || socket.assigns
    thread_id = e(assigns, :thread_id, e(assigns, :object, :id, nil))

    if thread_id do
      info("loading by thread_id")
      # debug(assigns)
      current_user = current_user(assigns) || current_user(socket)

      max_depth =  Config.get(:thread_default_max_depth, 3)

      with %{edges: replies, page_info: page_info} <- Bonfire.Social.Threads.list_replies(thread_id,
        current_user: current_user,
        after: e(assigns, :after, nil),
        max_depth: max_depth,
        thread_mode: e(assigns, :thread_mode, nil),
        reverse_order: e(assigns, :reverse_order, nil),
        showing_within: e(assigns, :showing_within, nil)
      ) do
        # debug(thread_id, "thread_id")
        # debug(replies, "queried replies")

        threaded_replies = if e(assigns, :thread_mode, nil) !=:flat and is_list(replies) and length(replies)>0, do: Bonfire.Social.Threads.arrange_replies_tree(replies)
        # debug(threaded_replies, "threaded_replies")

        assigns
        |> assigns_merge(
          loading: false,
          replies: replies,
          threaded_replies: threaded_replies,
          page_info: page_info,
          thread_id: thread_id
        )
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
