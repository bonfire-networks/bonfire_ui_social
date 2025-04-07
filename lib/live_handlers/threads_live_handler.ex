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

  def handle_params(
        %{"before" => cursor} = _attrs,
        _,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, [before: cursor], socket)
  end

  def handle_params(%{"before" => cursor, "context" => thread_id} = _attrs, _, socket) do
    live_more(thread_id, [before: cursor], socket)
  end

  # workaround for a weird issue appearing in tests
  # def handle_params(attrs, uri, socket) do
  #   case URI.parse(uri) do
  #     %{path: "/discussion/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
  #     %{path: "/post/" <> thread_id} -> live_more(thread_id, input_to_atoms(attrs), socket)
  #   end
  # end

  def handle_params(attrs, uri, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "mark_seen",
        %{"scope" => "all", "thread_id" => thread_id},
        %{assigns: %{count: count}} = socket
      )
      when is_binary(thread_id) do
    current_user = current_user_required!(socket)

    marked =
      if current_user do
        # Task.async(fn -> # TODO? asynchronously simply so the count is updated quicker for the user
        debug(thread_id, "mark_seen: all in thread")
        Bonfire.Social.Threads.mark_all_seen([thread_id: thread_id], current_user: current_user)
        # end)
      end

    {:noreply,
     socket
     |> assign(
       # TODO
       count: count - (marked || 0)
     )}
  end

  def handle_event(
        "load_more",
        %{"after" => _cursor} = attrs,
        %{assigns: %{thread_id: thread_id}} = socket
      ) do
    live_more(thread_id, input_to_atoms(attrs), socket)
  end

  def handle_event("load_more_replies", %{"id" => id, "level" => level}, socket) do
    debug("load extra reply level(s)")

    {level, _} = Integer.parse(level)

    # TODO: configurable - note: it seems to load one more than this, probably because of pagination
    load_more_replies_step = 2
    load_depth = level + load_more_replies_step

    opts = [
      current_user: current_user(assigns(socket)),
      max_depth: load_depth,
      thread_mode: e(assigns(socket), :thread_mode, nil),
      sort_by: e(assigns(socket), :sort_by, nil),
      sort_order: e(assigns(socket), :sort_order, nil)
    ]

    %{edges: replies, page_info: page_info} = Bonfire.Social.Threads.list_replies(id, opts)

    # TODO: do something with page_info? to support branch pagination

    if opts[:thread_mode] == :flat and is_list(replies) and
         e(assigns(socket), :reply_count, 0) > 0 do
      {:noreply,
       socket
       |> assign(depth_loaded: load_depth)
       |> insert_comments({:replies, replies})}
    else
      {:noreply,
       socket
       |> assign(depth_loaded: load_depth)
       |> insert_comments(
         {:threaded_replies,
          Threads.arrange_replies_tree(
            replies,
            opts
          ) || []}
       )}
    end
  end

  def handle_event("reply", %{"id" => reply_to_id} = _params, socket) do
    activity = e(assigns(socket), :activity, %{})

    reply_to =
      e(assigns(socket), :object, nil) ||
        e(activity, :object, nil) ||
        e(assigns(socket), :object_id, nil) ||
        e(activity, :object_id, nil)

    if reply_to_id == Enums.id(reply_to) do
      reply(reply_to, activity, socket)
    else
      reply(reply_to_id, activity, socket)
    end
  end

  def handle_event("reply", _params, socket) do
    activity = e(assigns(socket), :activity, %{})

    reply(
      e(assigns(socket), :object, nil) ||
        e(activity, :object, nil) ||
        e(assigns(socket), :object_id, nil) ||
        e(activity, :object_id, nil),
      activity,
      socket
    )
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
           e(assigns(socket), :activity, nil) || e(assigns(socket), :object, nil),
           e(assigns(socket), :thread_id, nil),
           limit: 50,
           current_user: current_user(assigns(socket))
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
    # permitted? = id && Bonfire.Common.Needles.exists?([id: id], current_user: current_user(assigns(socket))) |> debug("double check boundary upon receiving a LivePush")

    # if permitted?, do: # Note: now checking permission in ThreadLive
    if socket_connected?(socket) != false,
      do: maybe_send_update(Bonfire.UI.Social.ThreadLive, thread_id, new_reply: data)

    {:noreply, socket}
  end

  def live_more(thread_id, paginate, socket) do
    error(paginate, "paginate thread")

    opts =
      [
        current_user: current_user(assigns(socket)),
        paginate: paginate,
        thread_mode:
          (e(assigns(socket), :thread_mode, nil) ||
             Settings.get(
               [Bonfire.UI.Social.ThreadLive, :thread_mode],
               nil,
               assigns(socket)
             ) || :nested)
          |> debug("thread mode"),
        sort_by: e(assigns(socket), :sort_by, nil),
        max_depth: e(assigns(socket), :max_depth, nil),
        sort_order: e(assigns(socket), :sort_order, nil)
      ]
      |> debug()

    with %{edges: replies, page_info: page_info} <-
           Bonfire.Social.Threads.list_replies(
             thread_id,
             opts
           ) do
      replies =
        (e(assigns(socket), :replies, []) ++ replies)
        |> Enum.uniq()

      # |> debug("REPLIES")

      threaded_replies =
        if opts[:thread_mode] != :flat and is_list(replies) and replies != [],
          do:
            Threads.arrange_replies_tree(
              replies,
              opts
            ),
          else: []

      # debug(threaded_replies, "REPLIES threaded")

      {:noreply,
       socket
       |> assign(
         loading: false,
         replies: replies,
         threaded_replies: threaded_replies,
         page_info: page_info
       )}
    end
  end

  def reply(reply_to, activity, socket) do
    debug(reply_to, "reply!")

    # TODO: we should be getting the type from ActivityLive
    object_type =
      case e(assigns(socket), :object_type, nil) || Types.object_type(reply_to) do
        Bonfire.Data.Social.APActivity ->
          json = e(activity, :object, :json, nil) || e(assigns(socket), :object, :json, nil)
          e(json, "object", "type", nil) || e(json, "type", nil)

        other ->
          other
      end

    debug(e(assigns(socket), :object_boundary, nil), "object_boundary!")
    debug(e(assigns(socket), :published_in, nil), "published_in_id!")
    debug(object_type, "object_type!")
    reply_to_id = Enums.id(reply_to)

    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("reply"), reply_to),
         # TODO: can we use the preloaded object_boundaries rather than making an extra query
         true <- Bonfire.Boundaries.can?(current_user, :reply, reply_to_id) do
      published_in = e(assigns(socket), :published_in, nil)
      published_in_id = id(published_in)

      create_object_type = if(object_type == Bonfire.Data.Social.Message, do: :message)

      # TODO: don't re-load participants here as we already have the list (at least when we're in a thread)
      # TODO: include thread_id in list_participants/3 call
      participants =
        (e(assigns(socket), :participants, nil) ||
           Bonfire.Social.Threads.list_participants(Map.put(activity, :object, reply_to), nil,
             current_user: current_user
           ) || [])
        |> Enum.reject(&(e(&1, :character, :id, nil) in [id(current_user), published_in_id]))

      to_circles =
        if participants != [],
          do:
            Enum.map(participants, &{e(&1, :id, nil), e(&1, :character, :username, l("someone"))})

      mentions =
        if create_object_type != :message and participants != [],
          do: Enum.map_join(participants, " ", &("@" <> e(&1, :character, :username, ""))) <> " "

      # workaround for mobilizon not supported mentions

      thread_id =
        e(activity, :replied, :thread_id, nil) ||
          e(reply_to_id, :replied, :thread_id, nil)

      debug(mentions, "send activity to smart input")

      Bonfire.UI.Common.SmartInput.LiveHandler.open_with_text_suggestion(
        mentions,
        # we reply to objects, not
        [
          # reset_smart_input: false, # avoid double-reset
          reply_to_id: reply_to_id,
          context_id: thread_id,
          to_circles: to_circles || [],
          mentions: if(published_in_id, do: [published_in_id], else: []),
          #  do not allow editing recipients when replying to a group thread
          smart_input_opts: [
            create_object_type: create_object_type,
            recipients_editable: false,
            cw:
              e(activity, :sensitive, :is_sensitive, nil) &&
                e(activity, :object, :post_content, :summary, nil)
          ],
          to_boundaries: [
            if(published_in_id,
              do:
                {:clone_context,
                 e(published_in, :profile, :name, nil) || e(published_in, :named, :name, nil) ||
                   e(published_in, :name, nil)},
              else:
                Bonfire.Boundaries.preset_boundary_tuple_from_acl(
                  e(assigns(socket), :object_boundary, nil),
                  object_type
                )
            )
            |> debug("to_boundaries")
          ],
          activity_inception: "reply_to",
          # TODO: use assigns_merge and send_update to the ActivityLive component within smart_input instead, so that `update/2` isn't triggered again
          activity: activity,
          object: reply_to
        ],
        socket
      )

      {:noreply,
       socket
       |> maybe_push_event("mention_suggestions", %{text: mentions})}
    else
      false ->
        error(l("Sorry, you cannot reply to this"))

      other ->
        # for remote interaction redirect
        other
    end
  end

  def thread_init(socket) do
    # debug(assigns, "thread assigns")
    current_user = current_user(assigns(socket))
    object = e(assigns(socket), :object, nil) || e(assigns(socket), :activity, :object)

    thread_id =
      e(assigns(socket), :thread_id, nil) ||
        e(assigns(socket), :activity, :replied, :thread_id, nil) ||
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
      page: "thread",
      loading: socket_connected?(socket)
      # participants: participants
    )

    # |> debug
  end

  def load_thread_maybe_async(socket_or_opts, show_loader \\ true, reset_stream \\ false)

  def load_thread_maybe_async(%Phoenix.LiveView.Socket{} = socket, show_loader, reset_stream) do
    socket_connected = connected?(socket)
    current_user = current_user(assigns(socket))

    if (socket_connected || current_user != nil) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load async")
        pid = self()

        object = e(assigns(socket), :object, nil)
        thread_id = e(assigns(socket), :thread_id, nil) || id(object)
        component_id = e(assigns(socket), :id, nil) || thread_id

        apply_task(
          :start_async,
          fn ->
            # compute & send stats

            limit = 4

            participants =
              e(assigns(socket), :participants, []) ||
                Threads.list_participants(e(assigns(socket), :activity, nil) || object, thread_id,
                  limit: limit,
                  current_user: current_user
                )

            participant_count = Enum.count(participants)

            participant_count =
              if participant_count == limit,
                do: Threads.count_participants(thread_id, current_user: current_user),
                else: participant_count

            send_thread_updates(
              pid,
              component_id,
              %{
                skip_loading_comments: true,
                participants: participants,
                participant_count: participant_count,
                thread_boost_count:
                  Bonfire.Social.Boosts.count([in_thread: thread_id], current_user: current_user)
              }
            )
          end,
          socket: socket,
          id: "load_thread_meta"
        )

        apply_task(
          :start_async,
          fn ->
            # Query comments asynchronously
            {replies, assigns} = load_thread_assigns(socket, thread_id)

            # TODO: use first or last depending on sort order
            last_reply = List.first(replies)

            # send comments
            send_thread_updates(
              pid,
              component_id,
              {replies,
               assigns ++
                 [
                   loaded_async: thread_id,
                   reset_stream: reset_stream,
                   last_reply_id: id(last_reply) || false
                 ]}
            )
          end,
          socket: socket,
          id: "load_thread_comments"
        )
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      socket
      |> assign(loading: show_loader)
    else
      debug("socket not connected or not logged in, just load thread")
      load_thread(socket)
    end
  end

  def load_thread_maybe_async(socket_or_opts, _, _) do
    debug("no socket, just load thread")
    # debug(e(socket_or_opts, :assigns, nil), "not socket")
    load_thread(socket_or_opts)
  end

  def load_thread(socket) do
    with {replies, assigns} when is_list(replies) and is_list(assigns) <-
           load_thread_assigns(socket) do
      thread_mode = e(assigns, :thread_mode, nil)

      if thread_mode != :flat and is_list(replies) and
           e(assigns, :reply_count, 0) > 0 do
        debug("insert threaded_replies")

        socket
        |> assign(assigns)
        |> insert_comments(
          {:threaded_replies,
           Threads.arrange_replies_tree(replies,
             thread_mode: thread_mode,
             sort_by: e(assigns, :sort_by, nil),
             sort_order: e(assigns, :sort_order, nil)
           )}
        )
      else
        socket
        |> assign(assigns)
        |> insert_comments({:replies, replies})
      end
    else
      e ->
        error(e)

        socket
        |> assign_error("Could not load comments")
        |> assign(loading: false)
    end
  end

  def max_depth(ui_compact \\ nil),
    do:
      debug(
        Config.get(:thread_default_max_depth, 3) *
          if(ui_compact,
            do: 2,
            else: 1
          )
      )

  def load_thread_assigns(socket, thread_id \\ nil) do
    debug("load comments")
    thread_id = thread_id || e(assigns(socket), :thread_id, e(assigns(socket), :object, :id, nil))

    if thread_id do
      debug("loading by thread_id")
      # debug(assigns)

      thread_mode = e(assigns(socket), :thread_mode, nil)
      sort_by = e(assigns(socket), :sort_by, nil)
      sort_order = e(assigns(socket), :sort_order, nil)
      showing_within = e(assigns(socket), :showing_within, :thread)

      # TODO: use same logic as feeds preloads?
      # {preloads, postloads} =
      #   Bonfire.Social.Feeds.LiveHandler.activity_preloads_tuple_from_filters(%{
      #     sort_by: sort_by,
      #     sort_order: sort_order,
      #     showing_within: showing_within,
      #     thread_mode: thread_mode
      #   })
      preloads =
        Bonfire.Social.Feeds.LiveHandler.feed_extra_preloads_list(showing_within, thread_mode)

      max_depth = max_depth(assigns(socket)[:__context__][:ui_compact])

      with %{edges: replies, page_info: page_info} <-
             Threads.list_replies(thread_id,
               current_user: current_user(assigns(socket)),
               preload: preloads,
               after: e(assigns(socket), :after, nil),
               max_depth: max_depth,
               thread_mode: thread_mode,
               sort_by: sort_by,
               sort_order: sort_order,
               showing_within: showing_within
             ) do
        reply_count = length(replies)

        # debug(replies, "queried replies")
        debug(thread_id, "loaded #{reply_count} comments for thread")

        {replies,
         [
           loading: false,
           thread_mode: thread_mode,
           sort_by: sort_by,
           sort_order: sort_order,
           page_info: page_info,
           thread_id: thread_id,
           reply_count: reply_count,
           depth_loaded: max_depth,
           activity_preloads: {preloads, nil}
         ]
         |> debug("extra assigns")}
      end
    end
  end

  def send_thread_updates(
        pid \\ self(),
        thread_id,
        assigns,
        component \\ Bonfire.UI.Social.ThreadLive
      )

  def send_thread_updates(pid, thread_id, {replies, assigns}, component) when is_list(assigns) do
    thread_mode = e(assigns, :thread_mode, nil)

    if thread_mode != :flat and is_list(replies) and
         e(assigns, :reply_count, 0) > 0 do
      debug("send threaded replies to stream")

      Threads.arrange_replies_tree(replies,
        thread_mode: thread_mode,
        sort_by: e(assigns, :sort_by, nil),
        sort_order: e(assigns, :sort_order, nil)
      )
      |> {:threaded_replies, ...}
    else
      debug("send flat replies to stream")

      replies
      |> {:replies, ...}
    end
    |> send_thread_updates(pid, thread_id, assigns ++ [insert_stream: ...], component)
  end

  def send_thread_updates(pid, thread_id, assigns, component)
      when is_pid(pid) and (is_list(assigns) or is_map(assigns)) do
    debug(thread_id, "Sending comments update to")
    maybe_send_update(component, thread_id, assigns, pid)
  end

  def send_thread_updates(pid, thread_id, {:error, e}, _component) do
    debug(thread_id, "Returning error instead of comments")
    assign_error(%{}, e, pid)
  end

  def insert_comments(socket, replies, opts \\ [])

  def insert_comments(socket, {[], assigns}, _opts) do
    debug(assigns, "nothing to add")

    socket
    |> assign_generic(page_info: assigns[:page_info])

    # |> assign_generic(assigns)
  end

  def insert_comments(socket, {:replies, replies}, opts) do
    debug(replies, "insert flat replies into stream")

    # e(assigns(socket), :replies, [])

    maybe_stream_insert(
      socket,
      :replies,
      replies,
      opts
    )
  end

  def insert_comments(socket, {:threaded_replies, replies}, opts) do
    debug(replies, "insert threaded replies into stream")
    maybe_stream_insert(socket, :threaded_replies, replies, opts)
  end

  def insert_comments(socket, {:threaded_replies, replies, at}, opts) do
    debug(replies, "insert threaded replies into stream")
    maybe_stream_insert(socket, :threaded_replies, replies, opts ++ [at: at])
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
      if e(assigns(socket), :thread_mode, nil) != :flat and is_list(replies) and
           e(assigns(socket), :reply_count, 0) > 0 do
        :threaded_replies
      else
        :replies
      end
      |> insert_comments(socket, {..., replies}, opts)
    end
  end

  def maybe_subscribe(socket, thread_id) do
    if thread_id && !e(assigns(socket), :pubsub_subscribed, nil) do
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
