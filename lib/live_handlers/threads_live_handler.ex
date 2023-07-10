defmodule Bonfire.Social.Threads.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  alias Bonfire.Social.Threads

  def handle_params(
        %{"after" => cursor} = _attrs,
        _,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, [after: cursor], socket)
  end

  def handle_params(%{"after" => cursor, "context" => thread_id} = _attrs, _, socket) do
    live_more(thread_id, [after: cursor], socket)
  end

  # workaround for a weird issue appearing in tests
  def handle_params(attrs, uri, socket) do
    case URI.parse(uri) do
      %{path: "/discussion/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
      %{path: "/post/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
    end
  end

  def live_more(thread_id, paginate, socket) do
    # debug(paginate, "paginate thread")
    current_user = current_user(socket)

    with %{edges: replies, page_info: page_info} <-
           Bonfire.Social.Threads.list_replies(thread_id,
             current_user: current_user,
             paginate: paginate
           ) do
      replies =
        (e(socket.assigns, :replies, []) ++ replies)
        |> Enum.uniq()

      # |> debug("REPLIES")

      threaded_replies =
        if is_list(replies) and length(replies) > 0,
          do: Bonfire.Social.Threads.arrange_replies_tree(replies),
          else: []

      # debug(threaded_replies, "REPLIES threaded")

      {:noreply,
       socket
       |> assign(
         replies: replies,
         threaded_replies: threaded_replies,
         page_info: page_info
       )}
    end
  end

  def handle_event(
        "load_more",
        %{"after" => _cursor} = attrs,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, input_to_atoms(attrs), socket)
  end

  def handle_event("load_replies", %{"id" => id, "level" => level}, socket) do
    debug("load extra replies")
    {level, _} = Integer.parse(level)

    %{edges: replies} =
      Bonfire.Social.Threads.list_replies(id, socket: socket, max_depth: level + 3)

    if e(socket.assigns, :thread_mode, nil) != :flat and is_list(replies) and
         e(socket.assigns, :reply_count, 0) > 0 do
      {:noreply,
       insert_comments(
         socket,
         {:replies, replies}
       )}
    else
      {:noreply,
       insert_comments(
         socket,
         {:threaded_replies, Bonfire.Social.Threads.arrange_replies_tree(replies) || []}
       )}
    end
  end

  def handle_event(
        "list_participants",
        _attrs,
        %{assigns: %{already_loaded_participants: true}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "list_participants",
        _attrs,
        socket
      ) do
    {:noreply,
     assign(socket,
       participants:
         Threads.list_participants(
           e(socket.assigns, :activity, nil) || e(socket.assigns, :object, nil),
           e(socket.assigns, :thread_id, nil),
           limit: 50,
           current_user: current_user(socket)
         ),
       already_loaded_participants: true
     )}
  end

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

  def load_thread_maybe_async(%Phoenix.LiveView.Socket{} = socket, loading \\ true) do
    socket_connected = connected?(socket)
    current_user = current_user(socket)

    if (socket_connected || current_user != nil) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load async")
        pid = self()

        object = e(socket.assigns, :object, nil)
        thread_id = e(socket.assigns, :thread_id, nil) || id(object)

        async_task(fn ->
          # compute & send stats

          limit = 4

          participants =
            Threads.list_participants(e(socket.assigns, :activity, nil) || object, thread_id,
              limit: limit,
              current_user: current_user
            )

          participant_count = Enum.count(participants)

          participant_count =
            if participant_count == limit,
              do: Threads.count_participants(thread_id, current_user: current_user),
              else: participant_count

          maybe_send_update(
            pid,
            Bonfire.UI.Social.ActivityLive,
            e(socket.assigns, :main_object_component_id, nil),
            %{
              update_activity: true,
              participants: participants,
              participant_count: participant_count,
              thread_boost_count:
                Bonfire.Social.Boosts.count([in_thread: thread_id], current_user: current_user)
            }
          )
        end)

        async_task(fn ->
          # Query comments asynchronously
          {replies, assigns} = load_thread_assigns(socket)

          # send comments 
          send_thread_updates(
            pid,
            e(socket.assigns, :id, nil) || thread_id,
            {replies, assigns ++ [loaded_async: true]}
          )

          # TODO: use first or last depending on order
          last_reply = List.first(replies)

          # send stats that depend on the comment list
          maybe_send_update(
            pid,
            Bonfire.UI.Social.ActivityLive,
            e(socket.assigns, :main_object_component_id, nil),
            %{
              update_activity: true,
              last_reply_id: id(last_reply) || false
              # last_reply_path: path(last_reply),
              # reply_count: assigns[:reply_count]
            }
          )
        end)
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      socket
      |> assign(loading: loading)
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

  def max_depth(context, ui_compact \\ nil),
    do:
      Config.get(:thread_default_max_depth, 3) *
        if(
          ui_compact || e(context, :ui_compact, nil) ||
            Settings.get([:ui, :compact], false, context),
          do: 2,
          else: 1
        )

  def load_thread_assigns(socket) do
    debug("load comments")
    thread_id = e(socket.assigns, :thread_id, e(socket.assigns, :object, :id, nil))

    if thread_id do
      debug("loading by thread_id")
      # debug(assigns)
      current_user = current_user(socket)

      with %{edges: replies, page_info: page_info} <-
             Threads.list_replies(thread_id,
               current_user: current_user,
               after: e(socket.assigns, :after, nil),
               max_depth: max_depth(socket),
               thread_mode: e(socket.assigns, :thread_mode, nil),
               reverse_order: e(socket.assigns, :reverse_order, nil),
               showing_within: e(socket.assigns, :showing_within, nil)
             ) do
        reply_count = length(replies)

        # debug(replies, "queried replies")
        debug(thread_id, "loaded #{reply_count} comments for thread")

        {replies,
         [
           loading: false,
           thread_mode: e(socket.assigns, :thread_mode, nil),
           page_info: page_info,
           thread_id: thread_id,
           reply_count: reply_count
         ]}
      end
    end
  end

  defp send_thread_updates(
         pid \\ nil,
         thread_id,
         assigns,
         component \\ Bonfire.UI.Social.ThreadLive
       )

  defp send_thread_updates(pid, thread_id, {replies, assigns}, component) when is_list(assigns) do
    if e(assigns, :thread_mode, nil) != :flat and is_list(replies) and
         e(assigns, :reply_count, 0) > 0 do
      Threads.arrange_replies_tree(replies)
      # |> debug("send threaded replies to stream")
      |> {:threaded_replies, ...}
    else
      replies
      |> debug("send flat replies to stream")
      |> {:replies, ...}
    end
    |> send_thread_updates(pid, thread_id, assigns ++ [insert_stream: ...], component)
  end

  defp send_thread_updates(pid, thread_id, assigns, component)
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) do
    debug(thread_id, "Sending comments update to")
    maybe_send_update(pid, component, thread_id, assigns)
  end

  defp send_thread_updates(pid, thread_id, {:error, e}, _component) do
    debug(thread_id, "Returning error instead of comments")
    assign_error(%{}, e, pid)
  end

  def insert_comments(socket, replies, opts \\ [])

  def insert_comments(socket, {[], assigns}, opts) do
    debug(assigns, "nothing to add")

    socket
    |> assign_generic(page_info: assigns[:page_info])

    # |> assign_generic(assigns)
  end

  def insert_comments(socket, {:replies, replies}, opts) do
    debug(replies, "insert flat replies into stream")

    maybe_stream_insert(
      socket,
      :replies,
      List.wrap(replies) ++ Utils.e(socket.assigns, :replies, []),
      opts
    )
  end

  def insert_comments(socket, {:threaded_replies, replies}, opts) do
    debug(replies, "insert threaded replies into stream")
    maybe_stream_insert(socket, :threaded_replies, replies, opts)
  end

  def insert_comments(socket, {replies, assigns}, opts)
      when is_list(replies) and is_list(assigns) do
    socket
    |> assign_generic(assigns)
    |> insert_comments(replies, opts)
  end

  def insert_comments(socket, replies, opts) do
    # socket
    # |> assign_generic(feed: feed_edges)

    if e(replies, :replies, nil) do
      # temp workaround for when we're not actually getting a feed but rather a list of assigns for some reason
      socket
      |> assign_generic(replies)
    else
      if e(socket.assigns, :thread_mode, nil) != :flat and is_list(replies) and
           e(socket.assigns, :reply_count, 0) > 0 do
        :replies
      else
        :threaded_replies
      end
      |> insert_comments(socket, {..., replies}, opts)
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
