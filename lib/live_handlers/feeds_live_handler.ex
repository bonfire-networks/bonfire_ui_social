defmodule Bonfire.Social.Feeds.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  use Untangle
  alias Bonfire.Social.Activities
  alias Bonfire.Data.Social.Activity
  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.FeedActivities
  alias Bonfire.Social.FeedLoader

  @spec handle_params(any(), any(), any()) :: {:noreply, any()}
  def handle_params(
        %{"after" => _cursor_after} = attrs,
        _,
        socket
      ) do
    paginate_feed(
      e(assigns(socket), :feed_name, nil) || e(assigns(socket), :feed_id, nil) ||
        e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :id, nil),
      attrs,
      socket,
      hide_activities: false
    )
  end

  def handle_params(_attrs, _, socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", %{"context" => feed_id} = attrs, socket)
      when is_binary(feed_id) do
    paginate_feed(feed_id, attrs, socket, hide_activities: false)
  end

  def handle_event("load_more", attrs, socket) do
    paginate_feed(
      e(assigns(socket), :feed_name, nil) || e(assigns(socket), :feed_id, nil) ||
        e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :id, nil),
      attrs,
      socket,
      hide_activities: false
    )
  end

  def handle_event("preload_more", %{"context" => feed_id} = attrs, socket)
      when is_binary(feed_id) do
    paginate_feed(feed_id, attrs, socket, hide_activities: "infinite_scroll")
  end

  def handle_event("preload_more", attrs, socket) do
    paginate_feed(
      e(assigns(socket), :feed_name, nil) || e(assigns(socket), :feed_id, nil) ||
        e(assigns(socket), :feed_ids, nil) || e(assigns(socket), :id, nil),
      attrs,
      socket,
      hide_activities: "infinite_scroll"
    )
  end

  def handle_event("fetch_replies", params, socket) do
    ActivityPub.Federator.Fetcher.fetch_replies(
      [pointer: params["id"] || assigns(socket)[:post] || assigns(socket)[:object]],
      mode: :async
    )

    {:noreply, socket}
  end

  def handle_event("fetch_thread", params, socket) do
    ActivityPub.Federator.Fetcher.fetch_thread(
      [pointer: params["id"] || assigns(socket)[:post] || assigns(socket)[:object]],
      mode: :async
    )

    {:noreply, socket}
  end

  def handle_event("reply_to_activity", _params, socket) do
    activity = e(assigns(socket), :activity, %{})

    Bonfire.Social.Threads.LiveHandler.reply(
      e(assigns(socket), :object, nil) ||
        e(activity, :object, nil) ||
        e(assigns(socket), :object_id, nil) ||
        e(activity, :object_id, nil),
      activity,
      socket
    )
  end

  def handle_event("delete", %{"id" => id} = _params, socket) do
    # TODO: check permission
    with num when is_integer(num) <- Bonfire.Social.Activities.delete(id) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, l("Deleted from %{number} feeds!", number: num))}
    end
  end

  def handle_event("publish", %{"to" => to} = params, socket) do
    current_user = current_user(assigns(socket))
    activity = e(assigns(socket), :activity, nil) || id(params)

    if activity do
      object = e(assigns(socket), :object, nil) || activity

      to =
        case to do
          "instance_moderators" -> [notifications: Bonfire.Social.Flags.instance_moderators()]
          # TODO
          to -> to
        end
        |> FeedActivities.get_publish_feed_ids()

      # |> debug("tooo")

      # TODO: check permission
      with {:ok, _} <-
             FeedActivities.maybe_feed_publish(current_user, activity, object, to,
               current_user: current_user
             ) do
        {:noreply,
         socket
         |> assign_flash(:info, l("Done!"))}
      end
    else
      error("No activity to publish")
    end
  end

  def handle_event("open_activity", %{"ignore" => "true"} = _params, socket) do
    {:noreply, socket}
  end

  # def handle_event("open_activity", %{"permalink" => "/post/" <> _, "id" => id}, socket)
  #     when is_binary(id) and id != "" do
  #   preview_thread(socket, %{post_id: id})
  # end

  # def handle_event("open_activity", %{"id" => id}, socket) when is_binary(id) and id != "" do
  #   preview_thread(socket, %{object_id: id})
  # end

  def handle_event("open_activity", %{"permalink" => permalink} = _params, socket)
      when is_binary(permalink) and permalink != "" do
    debug("open_activity: redirect to the object URI")

    {:noreply,
     socket
     |> redirect_to(permalink)}
  end

  def handle_event("open_activity", _params, socket) do
    debug("open_activity with no valid params")
    {:noreply, socket}
  end

  # def handle_event("mark_seen", _params, %{assigns: %{activity: %{id: activity_id}}} = socket) when is_binary(feed_id) and is_binary(activity_id) do
  #   warn("TODO: mark as read: #{activity_id} in #{feed_id}")

  #   # maybe_send_update(Bonfire.UI.Common.BadgeCounterLive, feed_id, count--)

  #   {:noreply, socket}
  # end

  def handle_event(
        "mark_seen",
        %{"scope" => "all", "feed_id" => feed_id},
        %{assigns: %{count: count}} = socket
      )
      when is_binary(feed_id) do
    current_user = current_user_required!(socket)

    marked =
      if current_user do
        # Task.async(fn -> # TODO? asynchronously simply so the count is updated quicker for the user
        debug(feed_id, "mark_seen: all in feed")
        FeedActivities.mark_all_seen(feed_id, current_user: current_user)
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
        "mark_seen",
        %{"activity_id" => activity_id},
        %{assigns: %{count: count}} = socket
      )
      when is_binary(activity_id) and activity_id != "" do
    current_user = current_user_required!(socket)

    if current_user,
      do:
        apply_task(
          :start_async,
          fn ->
            # asynchronously simply so the count is updated quicker for the user
            debug(activity_id, "mark_seen")
            Bonfire.Social.Seen.mark_seen(current_user, activity_id)
          end,
          socket: socket,
          id: "mark_seen"
        )

    {:noreply,
     socket
     |> assign(count: count - 1)}
  end

  def handle_event("mark_seen", params, socket) do
    # warn(assigns, "mark as read: needed params not found")
    warn(params, "mark_seen: needed params not found")
    {:noreply, socket}
  end

  def handle_info({:count_increment, feed_ids}, socket) do
    debug(feed_ids, "count_increment")

    if socket_connected?(socket) != false,
      do: maybe_send_update(Bonfire.UI.Common.BadgeCounterLive, feed_ids, count_increment: 1)

    {:noreply, socket}
  end

  def handle_info({:new_activity, data}, socket) do
    debug(data[:feed_ids], "received new_activity for these feed ids")
    # dump(data)
    current_user = current_user(assigns(socket))

    permitted? =
      Bonfire.Common.Needles.exists?([id: e(data, :activity, :object, :id, nil)],
        current_user: current_user
      )
      |> debug("checked boundary upon receiving a LivePush - permitted?")

    if permitted? && is_list(data[:feed_ids]) do
      my_home_feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(current_user)

      feed_ids =
        if Enum.any?(data[:feed_ids], fn feed_id -> feed_id in my_home_feed_ids end) do
          # if activity targets any feeds we're following and/or meant to see in home feed, then target the home feed component
          data[:feed_ids] ++ [Bonfire.Social.Feeds.my_feed_id(:inbox, current_user)]
        else
          data[:feed_ids]
        end

      debug(feed_ids, "send_update to feeds")

      send_feed_updates(feed_ids, new_activity: data[:activity])
    else
      debug("I not have permission to view this new activity")
    end

    {:noreply, socket}
  end

  def handle_info({:hide_activity, activity}, socket) do
    if socket_connected?(socket), do: remove_activity(activity)

    {:noreply, socket}
  end

  def handle_info({:load_feed, key}, socket) do
    {entries, assigns} = feed_assigns(key, socket)

    {:noreply,
     socket
     |> assign_generic(assigns)
     |> insert_feed(entries)}
  end

  def remove_activity(activity) do
    maybe_send_update(ActivityLive, ActivityLive.component_id(id(activity), nil),
      activity_remove: true
    )
  end

  def reply_to_activity(js \\ %JS{}, target) do
    js
    |> JS.push(
      "Bonfire.Social.Feeds:reply_to_activity",
      target: target
    )
    |> Bonfire.UI.Common.SmartInput.LiveHandler.maximize()
  end

  defp send_feed_updates(pid \\ nil, feed_ids, assigns, component \\ Bonfire.UI.Social.FeedLive)

  # defp send_feed_updates(pid, feed_ids, {[], assigns}, component) when is_list(assigns) do
  #   debug("nothing to send") # NOTE: doing this means empty feed stays in loading state
  # end

  defp send_feed_updates(pid, feed_ids, {entries, assigns}, component) when is_list(assigns) do
    send_feed_updates(pid, feed_ids, assigns ++ [insert_stream: %{feed: entries}], component)
  end

  defp send_feed_updates(
         pid,
         "Bonfire-UI-Social-FeedLive_" <> _ = feed_id,
         assigns,
         component
       )
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) do
    debug("#{feed_id}", "Sending feed update to component")
    debug(assigns)
    maybe_send_update(component, feed_id, assigns, pid)
  end

  defp send_feed_updates(pid, feed_id, assigns, component)
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) and
              is_binary(feed_id) do
    # Format the feed_id to match the expected component ID pattern
    debug(feed_id, "Sending feed update to properly formatted feed component ID")
    debug(assigns)
    maybe_send_update(component, feed_id, assigns, pid)
  end

  defp send_feed_updates(pid, feed_ids, assigns, component)
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) and
              is_list(feed_ids) do
    # Handle a list of feed IDs by formatting each one and sending updates to all
    debug(feed_ids, "Sending feed updates to multiple feeds")

    Enum.each(feed_ids, fn feed_id when is_binary(feed_id) ->
      component_id = "Bonfire-UI-Social-FeedLive__for_#{feed_id}"
      debug(component_id, "Sending feed update to properly formatted feed component ID")
      maybe_send_update(component, component_id, assigns, pid)
    end)
  end

  defp send_feed_updates(pid, feed_id, assigns, component)
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) do
    maybe_send_update(component, feed_id, assigns)
  end

  defp send_feed_updates(pid, feed_id, {:error, e}, _component) do
    debug(feed_id, "Returning error instead of feed")
    assign_error(%{}, e, pid)
  end

  def paginate_feed(feed_id, attrs, socket, opts \\ [])

  # def paginate_feed("user_" <> selected_tab_and_user_id, attrs, socket, _opts) do
  #   debug(selected_tab_and_user_id, "paginate user feed")

  #   {:noreply,
  #    socket
  #    |> insert_feed(load_user_feed_assigns(selected_tab_and_user_id, attrs, socket))}
  # end

  # def paginate_feed(feed, attrs, socket, opts)
  #     when feed in [:likes, :bookmarks, :flags, :curated] do
  #   attrs = input_to_atoms(attrs)

  #   opts = opts ++ Keyword.new(attrs) ++ [paginate?: true, current_user: current_user(socket)]

  #   do_paginate_fetch_assign_feed(feed, opts, socket)
  # end

  def paginate_feed(feed_id, attrs, socket, opts) do
    opts =
      paginate_opts(attrs, socket, opts)
      |> debug("paginate_opts")

    # if(current_user_id(opts) && feed_id == Bonfire.Social.Feeds.my_feed_id(:inbox, opts)) do
    #   debug(
    #     "Feeds - paginate - the feed_id assigned in the view is current user's inbox, so load that"
    #   )

    #   paginate_fetch_assign_default(
    #     opts,
    #     socket
    #   )
    # else
    (feed_id || :default)
    |> debug("feed_id")
    |> paginate_fetch_assign_feed(
      opts,
      socket
    )

    # end
  end

  # def paginate_default_feed(attrs, socket, opts \\ []) do
  #   debug("Feeds - paginate - there's no feed_id, so load the default")

  #   paginate_fetch_assign_default(
  #     paginate_opts(attrs, socket, opts),
  #     socket
  #   )
  # end

  def paginate_opts(attrs, socket, opts) do
    attrs = input_to_atoms(attrs)

    opts =
      to_options(socket)
      |> Keyword.merge(opts)
      |> Keyword.put(
        :time_limit,
        attrs[:time_limit] || e(assigns(socket), :feed_filters, :time_limit, nil)
      )

    opts
    |> Keyword.put(
      :paginate,
      Keyword.merge(
        Keyword.new(attrs),
        Activities.order_pagination_opts(
          opts[:sort_by] || e(assigns(socket), :feed_filters, :sort_by, nil),
          opts[:sort_order] || e(assigns(socket), :feed_filters, :sort_order, nil)
        )
      )
    )
  end

  def paginate_fetch_assign_default(opts, socket) do
    # || current_account(socket)
    current = current_user(assigns(socket))

    feed_or_tuple =
      if not is_nil(current) do
        feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, current)
        feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(current)
        {feed_id, feed_ids}
      else
        # fallback to showing instance feed
        Bonfire.Social.Feeds.named_feed_id(:local)
      end

    # FIXME?
    {entries, assigns} = feed_assigns(feed_or_tuple, socket)

    {:noreply,
     socket
     |> assign_generic(
       feed_update_mode: "append",
       hide_activities: opts[:hide_activities],
       feed_count: Enum.count(entries || [])
     )
     |> assign_generic(assigns)
     |> insert_feed(entries, opts)}
  end

  defp paginate_fetch_assign_feed(:default, opts, socket),
    do: paginate_fetch_assign_default(opts, socket)

  defp paginate_fetch_assign_feed(feed_id, opts, socket) do
    Keyword.put_new_lazy(opts, :activity_preloads, fn ->
      e(assigns(socket), :activity_preloads, nil) ||
        activity_preloads_tuple_from_filters(e(assigns(socket), :feed_filters, %{}),
          showing_within: e(assigns(socket), :showing_within, nil)
        )
    end)
    |> do_paginate_fetch_assign_feed(feed_id, ..., socket)
  end

  defp do_paginate_fetch_assign_feed(feed_id, opts, socket) do
    filters =
      e(assigns(socket), :filters, %{})

    feed =
      FeedLoader.feed(
        feed_id,
        filters,
        opts
      )

    {:noreply,
     socket
     |> assign_generic(
       feed_update_mode: "append",
       hide_activities: opts[:hide_activities],
       feed_count: Enum.count(e(feed, :edges, [])),
       time_limit: opts[:time_limit],
       previous_page_info: e(assigns(socket), :page_info, nil),
       page_info: e(feed, :page_info, []),
       feed_filters: filters,
       activity_preloads: opts[:activity_preloads]
     )
     |> insert_feed(e(feed, :edges, []), opts)}
  end

  @spec insert_feed(any(), any(), any()) :: any()
  def insert_feed(socket, feed_edges, opts \\ [])

  def insert_feed(socket, {[], assigns}, opts) do
    if opts[:reset] do
      debug(assigns, "nothing to add, but still should reset")

      socket
      |> insert_feed([], opts)
      |> assign_generic(assigns)
      |> assign_generic(
        previous_page_info: e(assigns(socket), :page_info, nil),
        loading: false,
        reloading: false
      )
    else
      debug(assigns, "nothing to add")

      socket
      |> assign_generic(assigns)
      |> assign_generic(
        previous_page_info: e(assigns(socket), :page_info, nil),
        page_info: assigns[:page_info],
        loading: false,
        reloading: false
      )

      # |> assign_generic(assigns)
    end
  end

  def insert_feed(socket, {:error, assigns}, _opts) do
    socket
    |> assign_error(assigns)
  end

  def insert_feed(socket, {feed_edges, assigns}, opts) do
    debug(length(feed_edges), "inserting edges and assigns")

    socket
    |> assign_generic(assigns)
    |> insert_feed(feed_edges, opts)
  end

  def insert_feed(socket, feed_edges, opts) do
    # socket
    # |> assign_generic(feed: feed_edges)
    if (feed_edges != [] and Keyword.keyword?(feed_edges)) or
         e(feed_edges, :feed_component_id, nil) do
      debug(
        feed_edges,
        "workaround for when we're not actually getting a feed but just a list of assigns (probably because the feed is being loaded async)"
      )

      socket
      |> assign_generic(feed_edges)
    else
      debug(opts, "insert feed into stream with opts")

      socket
      |> assign_generic(
        loading: false,
        reloading: false
      )
      |> maybe_stream_insert(:feed, feed_edges || [], opts)
    end
  end

  def assign_feed(socket, assigns, opts \\ [])

  def assign_feed(socket, {_feed_edges, assigns}, _opts) do
    socket
    |> assign_generic(assigns)
  end

  def assign_feed(socket, assigns, _opts) do
    socket
    |> assign_generic(assigns)
  end

  # defp feed_filter_assigns(%{"object_types" => "discussion" = filter}),
  #   do: [
  #     tab_path_suffix: "/#{filter}",
  #     page_title: l("Discussions"),
  #     page_header_icon: "ri:discuss-line"
  #   ]

  # defp feed_filter_assigns(%{"object_types" => "post" = filter}),
  #   do: [
  #     tab_path_suffix: "/#{filter}",
  #     page_title: l("Posts"),
  #     page: "posts",
  #     page_header_icon: "ri:chat-2-line"
  #   ]

  # defp feed_filter_assigns(%{"object_types" => filter}),
  #   do: [
  #     tab_path_suffix: "/#{filter}",
  #     page_title: filter,
  #     showing_within: Types.maybe_to_atom(filter)
  #   ]

  # defp feed_filter_assigns(_),
  #   do: [tab_path_suffix: nil, 
  #   page_title: l("Activities"), 
  #   page_header_icon: "carbon:home"]

  # @decorate time()

  def feed_assigns_maybe_async(other, socket, show_loader \\ true, reset_stream \\ false)

  def feed_assigns_maybe_async(
        {feed_name, filters_or_custom_query_or_feed_id_or_ids},
        socket,
        show_loader,
        reset_stream
      ) do
    feed_name =
      feed_name
      # |> debug()
      |> FeedLoader.feed_name_or_default(current_user_id(socket))

    # |> debug()

    debug(feed_name, "feed_name")
    debug(filters_or_custom_query_or_feed_id_or_ids, "filters_or_custom_query_or_feed_id_or_ids")

    # ++ feed_filter_assigns(filters_or_custom_query_or_feed_id_or_ids) 
    assigns =
      (feed_default_assigns(feed_name, socket) ++ [loading: show_loader])
      |> debug("start by setting feed_default_assigns + feed_filter_assigns")

    feed_assigns_maybe_async_load(
      {feed_name, filters_or_custom_query_or_feed_id_or_ids},
      assigns,
      socket,
      reset_stream
    )
  end

  def feed_assigns_maybe_async(feed_name, socket, show_loader, reset_stream) do
    feed_name =
      feed_name
      # |> debug()
      |> FeedLoader.feed_name_or_default(current_user_id(socket))

    # |> debug()

    assigns =
      (feed_default_assigns(feed_name, socket) ++ [loading: show_loader])
      |> debug("start by setting feed_default_assigns")

    feed_assigns_maybe_async_load(
      {feed_name, assigns[:feed_ids] || assigns[:feed_id]},
      assigns,
      socket,
      reset_stream
    )
  end

  # def page_header_asides(socket, component_id) do
  #   [
  #     page_header_aside: [
  #       {Bonfire.UI.Social.FeedExtraControlsLive,
  #        [
  #          event_target: component_id,
  #          sort_by: e(assigns(socket), :feed_filters, :sort_by, nil),
  #          time_limit: e(assigns(socket), :feed_filters, :sort_by, 7),
  #          sort_order: e(assigns(socket), :sort_order, false)
  #        ]}
  #     ]
  #   ]
  # end

  def feed_default_assigns(:my = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.my_feed_id(:inbox, socket)
      |> debug(feed_name)

    feed_ids =
      Bonfire.Social.Feeds.my_home_feed_ids(socket)
      |> debug("feed_ids")

    component_id = component_id([feed_id] ++ feed_ids, assigns(socket))

    Keyword.merge(
      [
        feed_name: feed_name,
        feed_id: feed_id,
        feed_ids: feed_ids,
        feed_component_id: component_id
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns(:explore = feed_name, socket) do
    feed_id = "0AND0MSTRANGERS0FF1NTERNET"

    component_id =
      component_id(
        [
          feed_id,
          Bonfire.Social.Feeds.named_feed_id(:activity_pub),
          Bonfire.Social.Feeds.named_feed_id(:local)
        ],
        assigns(socket)
      )

    Keyword.merge(
      [
        feed_name: feed_name,
        feed_id: feed_id,
        feed_component_id: component_id
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns(:remote = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:activity_pub)
      |> debug(feed_name)

    component_id = component_id(feed_id, assigns(socket))

    Keyword.merge(
      [
        feed_name: feed_name,
        feed_id: feed_id,
        feed_component_id: component_id
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns(:local = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:local)
      |> debug(feed_name)

    component_id = component_id(feed_id, assigns(socket))

    Keyword.merge(
      [
        feed_name: feed_name,
        feed_id: feed_id,
        feed_component_id: component_id
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket)
      when is_atom(feed_name) do
    feed_default_assigns(feed_name, socket) ++
      [
        # feed_name: feed_name,
        # feed_id: feed_name,
        selected_tab: feed_name,
        feed_filters: filters_or_custom_query_or_feed_id_or_ids
        # feed_component_id: component_id(feed_name, assigns(socket)),
        # feed: nil,
        # page_info: nil
      ]
  end

  def feed_default_assigns({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket)
      when is_binary(feed_name) do
    Keyword.merge(
      [
        feed_name: feed_name,
        selected_tab: feed_name,
        feed_id: feed_name,
        feed_filters: filters_or_custom_query_or_feed_id_or_ids,
        feed_component_id: component_id(feed_name, assigns(socket))
        # feed: nil,
        # page_info: nil
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns(:default, socket) do
    FeedLoader.feed_name_or_default(:default, socket)
    |> feed_default_assigns(socket)
  end

  def feed_default_assigns(feed_name, socket) when is_atom(feed_name) do
    Keyword.merge(
      [
        feed_name: feed_name,
        feed_id: feed_name,
        selected_tab: feed_name,
        feed_component_id: component_id(feed_name, assigns(socket))
        # feed: nil,
        # page_info: nil
      ],
      feed_default_assigns_from_preset(feed_name, socket)
    )
  end

  def feed_default_assigns(other, socket) do
    debug(other)

    [
      feed_component_id: component_id(other, assigns(socket))
      # feed: nil,
      # page_info: nil
    ]
  end

  def feed_default_assigns_from_preset(feed_name, opts) do
    # TODO: optimise by avoiding loading the preset twice (here and in prepare_filters_assigns_preloads_posloads)
    with {:ok, %{assigns: assigns}} <-
           Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, opts) do
      assigns
    else
      other ->
        debug(other, "Could not find feed preset with assigns")
        []
    end
  end

  defp component_id(_feed_id_or_tuple, %{feed_component_id: feed_component_id} = _assigns)
       when not is_nil(feed_component_id),
       do: feed_component_id

  defp component_id(feed_id_or_tuple, _assigns),
    do:
      ComponentID.new(Bonfire.UI.Social.FeedLive, feed_id_or_tuple |> feed_id_only())
      #  "feed_#{feed_id_or_tuple |> feed_id_only() || "unknown"}"
      |> debug("the_feed_component_id")

  # @decorate time()
  defp feed_assigns_maybe_async_load(
         feed_name_id_or_tuple,
         assigns,
         socket,
         # \\ false
         reset_stream
       )

  # defp feed_assigns_maybe_async_load(feed_name, assigns, %{assigns: %{loading: false}} = socket, reset_stream) do
  #   debug("Skip loading feed...")
  #   []
  # end
  defp feed_assigns_maybe_async_load(
         feed_name_id_or_tuple,
         assigns,
         %Phoenix.LiveView.Socket{} = socket,
         reset_stream
       ) do
    socket_connected = user_socket_connected?(socket)
    opts = to_options(socket)

    if (socket_connected || current_user(opts)) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load feed async")
        pid = self()

        apply_task(
          :start_async,
          fn ->
            debug(feed_name_id_or_tuple, "Query activities asynchronously")

            with {entries, new_assigns} when is_list(new_assigns) <-
                   feed_assigns(feed_name_id_or_tuple, opts) do
              # |> debug("feed_assigns")
              send_feed_updates(
                pid,
                assigns[:feed_component_id] || assigns[:feed_id] || :feeds,
                {entries,
                 new_assigns ++
                   [
                     loaded_async: true,
                     reset_stream: reset_stream,
                     loading: false,
                     reloading: false
                   ]},
                Bonfire.UI.Social.FeedLive
              )
            else
              {:error, e} ->
                error(e, "error returned by feed_assigns")
                assign_error(socket, Bonfire.Common.Errors.error_msg(e) || e, pid)

              e ->
                error(e, "received invalid response from feed_assigns")
                assign_error(socket, "There was an error when trying to load the feed.", pid)
            end
          end,
          socket: socket,
          id: feed_name_id_or_tuple
        )

        # end of async
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      # return temporary assigns in the meantime
      assigns
    else
      debug("socket not connected or not logged in, load feed synchronously")

      feed_assigns_non_live(
        feed_id_only(feed_name_id_or_tuple),
        assigns,
        Map.merge(
          e(assigns, :feed_filters, nil) || e(assigns(socket), :feed_filters, %{}),
          feed_filters_only(feed_name_id_or_tuple)
        ),
        opts
      )
    end
  end

  defp feed_assigns_maybe_async_load(feed_name_id_or_tuple, assigns, socket, _reset_stream) do
    # non-Socket connection
    feed_assigns_non_live(
      feed_id_only(feed_name_id_or_tuple),
      assigns,
      Map.merge(
        e(assigns, :feed_filters, nil) || e(assigns(socket), :feed_filters, %{}),
        feed_filters_only(feed_name_id_or_tuple)
      ),
      socket
    )
  end

  def feed_assigns_non_live(feed_id, assigns, feed_filters, socket_or_opts) do
    opts = to_options(socket_or_opts)

    case debug(opts ++ [cache: e(opts, :cache_strategy, nil) == :guest_cache])
         |> feed_assigns({feed_id, feed_filters}, ...) do
      {:error, e} -> {:error, e}
      {entries, feed_assigns} when is_list(feed_assigns) -> {entries, assigns ++ feed_assigns}
      e -> e
    end
  end

  defp feed_id_only({feed_id, _feed_ids}), do: feed_id
  defp feed_id_only(feed_id), do: feed_id

  defp feed_filters_only({feed_id, %{} = filters}), do: filters
  defp feed_filters_only(_), do: %{}

  @decorate time()
  defp feed_assigns(feed, opts)

  # defp feed_assigns({:flags, _filters}, opts) do
  #   # NOTE: we don't support extra filter on likes for now
  #   feed_assigns(:flags, opts)
  # end

  # defp feed_assigns({:curated, _filters}, opts) do
  #   # NOTE: we don't support extra filter on likes for now
  #   feed_assigns(:curated, opts)
  # end

  # defp feed_assigns({:likes, _filters}, opts) do
  #   # NOTE: we don't support extra filter on likes for now
  #   feed_assigns(:likes, opts)
  # end

  defp feed_assigns({:my, feed_id_or_ids}, opts) when is_list(feed_id_or_ids) do
    if Keyword.keyword?(feed_id_or_ids) do
      debug("looks like filters passed as a keyword list")
      feed_assigns({:my, Map.new(feed_id_or_ids)}, opts)
    else
      # My Feed
      debug("A. Starting feed_assigns for my feed")

      with {feed_filters, assigns, preloads, postloads} <-
             prepare_filters_assigns_preloads_posloads(
               :my,
               opts
             ),
           opts = opts ++ [preload: preloads],
           %{} = feed <-
             feed_id_or_ids
             |> debug("feed_id_or_ids")
             |> FeedLoader.my_feed(opts, ...) do
        merge_feed_assigns(
          feed,
          [activity_preloads: {preloads, postloads}, feed_filters: feed_filters] ++ assigns,
          e(opts, :page_info, nil)
        )
      end
    end
  end

  # defp feed_assigns("user_" <> tab_and_user_or_other_id, opts) do
  #   [tab, user_or_other_id] =
  #     String.split(tab_and_user_or_other_id, "_", parts: 2)
  #     |> debug("tab and user_or_other_id")

  #   # FIXME socket/opts mismatch
  #   load_user_feed_assigns(tab, user_or_other_id, [], %{assigns: opts})
  #   # |> debug()
  # end

  # defp feed_assigns({"user_" <> tab_and_user_or_other_id, other}, opts) do
  #   debug(other, "load user/other timeline: #{tab_and_user_or_other_id}")

  #   [tab, user_or_other_id] =
  #     String.split(tab_and_user_or_other_id, "_", parts: 2)
  #     |> debug("tab and user_or_other_id")

  #   # FIXME socket/opts mismatch
  #   load_user_feed_assigns(tab, user_or_other_id, other, %{assigns: opts})
  #   # |> debug()
  # end

  defp feed_assigns({{feed_id, nil}, %{} = feed_filters}, opts) when feed_filters != %{} do
    feed_assigns({feed_id, feed_filters}, opts)
  end

  defp feed_assigns({feed_name_or_id, %{} = feed_filters}, opts) when feed_filters != %{} do
    with {feed_filters, assigns, preloads, postloads} <-
           prepare_filters_assigns_preloads_posloads(
             Map.put(feed_filters, :feed_name, feed_name_or_id),
             opts
           ),
         opts = opts ++ [preload: preloads],
         %{} = feed <- FeedLoader.feed(feed_name_or_id, feed_filters, opts) do
      merge_feed_assigns(
        feed,
        [activity_preloads: {preloads, postloads}, feed_filters: feed_filters] ++ assigns,
        e(opts, :page_info, nil)
      )
    end
  end

  defp feed_assigns(feed_id, opts) when is_binary(feed_id) do
    feed_filters = e(opts, :feed_filters, %{})

    with {feed_filters, assigns, preloads, postloads} <-
           prepare_filters_assigns_preloads_posloads(
             Map.put(feed_filters, :feed_name, feed_id),
             opts
           ),
         opts = opts ++ [preload: preloads],
         %{} = feed <-
           feed_id
           |> debug("feed_id")
           |> FeedLoader.feed(..., feed_filters, opts) do
      merge_feed_assigns(
        feed,
        [activity_preloads: {preloads, postloads}, feed_filters: feed_filters] ++ assigns,
        e(opts, :page_info, nil)
      )
    end
  end

  # defp feed_assigns(:flags = _feed_id, opts) do
  #   current_user_required!(opts)

  #   opts =
  #     opts ++
  #       [
  #         paginate?: true,
  #         include_flags: :mediate
  #         # preload: preloads
  #       ]

  #   with %{} = feed <-
  #          Bonfire.Social.Flags.list_preloaded(opts) do
  #     merge_feed_assigns(
  #       feed,
  #       [loading: false],
  #       e(opts, :page_info, nil)
  #     )
  #   end
  # end

  defp feed_assigns(:curated = _feed_id, opts) do
    opts =
      opts ++
        [
          object_types: [],
          paginate?: true
          # preload: preloads
        ]

    # opts = paginate_opts(%{}, socket, opts)

    with %{} = feed <-
           Bonfire.Social.Pins.list_instance_pins(opts) do
      merge_feed_assigns(
        feed,
        [],
        e(opts, :page_info, nil)
      )
    end
  end

  # Add pagination ->
  # defp feed_assigns(:likes = _feed_id, opts) do
  #   current_user_required!(opts)

  #   opts =
  #     opts ++
  #       [
  #         paginate?: true
  #         # preload: preloads
  #       ]

  #   # opts = paginate_opts(%{}, socket, opts)

  #   with %{} = feed <-
  #          Bonfire.Common.Utils.maybe_apply(
  #            Bonfire.Social.Likes,
  #            :list_my,
  #            [opts]
  #          ) do
  #     merge_feed_assigns(
  #       feed,
  #       [loading: false],
  #       e(opts, :page_info, nil)
  #     )
  #   end
  # end

  defp feed_assigns(%Ecto.Query{} = custom_query, opts) do
    feed_filters = e(opts, :feed_filters, %{})

    with {feed_filters, assigns, preloads, postloads} <-
           prepare_filters_assigns_preloads_posloads(
             feed_filters,
             opts
           ),
         opts = opts ++ [preload: preloads],
         %{} = feed <-
           custom_query
           |> debug("custom_query")
           |> FeedLoader.feed(feed_filters, opts) do
      merge_feed_assigns(
        feed,
        [activity_preloads: {preloads, postloads}, feed_filters: feed_filters] ++ assigns,
        e(opts, :page_info, nil)
      )
    end
  end

  defp feed_assigns(feed_name, opts) when is_atom(feed_name) do
    feed_id =
      case Bonfire.Social.Feeds.named_feed_id(feed_name, opts) do
        feed_id when feed_id != feed_name ->
          feed_id

        other ->
          warn(other, "unrecognised feed_name")
          nil
      end

    feed_filters = e(opts, :feed_filters, %{})

    with {feed_filters, assigns, preloads, postloads} <-
           prepare_filters_assigns_preloads_posloads(
             Map.put(feed_filters, :feed_name, feed_name),
             opts
           ),
         opts = opts ++ [preload: preloads],
         %{} = feed <-
           FeedLoader.feed(
             if(feed_id, do: {feed_name, feed_id}, else: feed_name) |> debug("fnid"),
             feed_filters,
             opts
           ) do
      merge_feed_assigns(
        feed,
        [
          feed_name: feed_name,
          feed_id: feed_id,
          activity_preloads: {preloads, postloads},
          feed_filters: feed_filters
        ] ++ assigns,
        e(opts, :page_info, nil)
      )
    end
  end

  # defp feed_assigns(feed_name, %{feed_filters: feed_filters} = opts)
  #      when not is_nil(feed_filters) and feed_filters != [] do
  #   debug(feed_filters, "use feed_filters")
  #   feed_assigns({feed_name, feed_filters}, opts)
  # end

  defp feed_assigns({feed_id, other}, opts) when is_atom(feed_id) and not is_nil(feed_id) do
    warn(other, "ignoring unrecognised param, for feed #{inspect(feed_id)}")
    feed_assigns(feed_id, opts)
  end

  defp feed_assigns({feed_id, other}, opts) do
    warn(feed_id, "unrecognised feed_id")
    warn(other, "unrecognised param")
    feed_assigns(feed_id || other, opts)
  end

  defp feed_assigns(feed_id_or_name, opts) do
    case e(opts, :feed_filters, []) do
      [] ->
        error(feed_id_or_name, "Unrecognised feed")

      feed_filters ->
        debug(feed_filters, "use feed_filters")
        feed_assigns({feed_id_or_name, feed_filters}, opts)
    end
  end

  @decorate time()
  def activity_update_many(assigns_sockets, opts) do
    feed_live_update_many_preload_mode = feed_live_update_many_preload_mode()

    override_live_update_many_preload_mode =
      case feed_live_update_many_preload_mode() do
        # we also want to do other preloads inline
        :async_actions -> :inline
        other -> other
      end

    # |> debug("feed_live_update_many_preload_mode")

    {first_assigns, _} = List.first(assigns_sockets)

    opts =
      opts ++
        [
          live_update_many_preload_mode: override_live_update_many_preload_mode,
          preload_status_key: :preloaded_async_activities,
          return_assigns_socket_tuple: true,
          id:
            e(first_assigns, :feed_name, nil) || e(first_assigns, :feed_id, nil) ||
              e(first_assigns, :thread_id, nil) || id(first_assigns)
        ]

    # FIXME: can't just use the first component's assigns to define our opts, but rather check all of them and group by different opts (specifically preloads) and execute them separately (in parallel), or merge them
    {current_user, opts} =
      opts_for_update_many_async(List.first(assigns_sockets), opts)

    assigns_sockets =
      assigns_sockets
      |> Bonfire.Boundaries.LiveHandler.maybe_check_boundaries(
        Keyword.merge(opts,
          verbs: [:read],
          current_user: current_user,
          return_assigns_socket_tuple: true
        )
      ) ||
        assigns_sockets

    non_batch_opts =
      Keyword.merge(opts,
        assigns_to_params_fn: &assigns_to_params/1,
        preload_fn: &preload_extras/3
      )

    batch_opts = [
      Utils.maybe_apply(
        Bonfire.Boundaries.LiveHandler,
        :update_many_opts,
        [
          Keyword.merge(opts,
            verbs: [:read]
          )
        ]
      ),
      # TODO: add Likes, Bookmarks, etc as in `actions_update_many`
      non_batch_opts
    ]

    case feed_live_update_many_preload_mode do
      :async_actions ->
        # |> debug("ccccccc")
        update_many_async(
          current_user,
          assigns_sockets,
          non_batch_opts
        )

      :inline ->
        # |> debug("ccccccc")
        batch_update_many_async(
          current_user,
          assigns_sockets,
          batch_opts,
          opts
        )

      :async_total ->
        # |> debug("ccccccc")
        batch_update_many_async(
          current_user,
          assigns_sockets,
          batch_opts,
          opts
        )

      _ ->
        false
    end || assigns_sockets
  end

  @decorate time()
  def actions_update_many(assigns_sockets, opts) do
    if feed_live_update_many_preload_mode() == :async_actions do
      {first_assigns, _} = List.first(assigns_sockets)

      opts =
        opts ++
          [
            return_assigns_socket_tuple: true,
            preload_status_key: :preloaded_async_actions,
            live_update_many_preload_mode: :user_async_or_skip,
            id:
              e(first_assigns, :feed_name, nil) || e(first_assigns, :feed_id, nil) ||
                e(first_assigns, :thread_id, nil) || id(first_assigns)
          ]

      # FIXME: can't just use the first component's assigns to define our opts, but rather check all of them and group by different opts (specifically preloads) and execute them separately (in parallel), or merge them
      {current_user, opts} =
        opts_for_update_many_async(List.first(assigns_sockets), opts)

      # |> debug("opts_for_update_many_async")

      # |> debug("ccccccc")
      batch_update_many_async(
        current_user,
        assigns_sockets,
        if(opts[:showing_within] != :messages,
          do: [
            Utils.maybe_apply(
              Bonfire.Boundaries.LiveHandler,
              :update_many_opts,
              [
                opts ++
                  [
                    verbs: [:read]
                  ]
              ]
            ),
            Utils.maybe_apply(
              Bonfire.Social.Boosts.LiveHandler,
              :update_many_opts,
              [opts]
            )
          ],
          else: []
        ) ++
          [
            Utils.maybe_apply(
              Bonfire.Social.Likes.LiveHandler,
              :update_many_opts,
              [opts]
            ),
            if(
              module_enabled?(Bonfire.UI.Reactions.BookmarkActionLive, current_user: current_user),
              do:
                Utils.maybe_apply(
                  Bonfire.Social.Bookmarks.LiveHandler,
                  :update_many_opts,
                  [opts]
                )
            )
          ],
        opts
      ) || assigns_sockets

      # |> debug
    else
      assigns_sockets
    end
  end

  def feed_live_update_many_preload_mode,
    do:
      (ProcessTree.get(:feed_live_update_many_preload_mode) ||
         Config.get(:feed_live_update_many_preload_mode) || :async_actions)
      |> debug()

  defp assigns_to_params(assigns) do
    activity = activity_with_object_from_assigns(assigns)
    object = e(assigns, :object, nil) || e(activity, :object, nil)

    %{
      component_id: assigns.id,
      activity: activity,
      object: object,
      object_id: id(activity) || id(object),
      activity_preloads: ed(assigns, :activity_preloads, nil),
      showing_within: ed(assigns, :showing_within, nil),
      thread_mode: ed(assigns, :thread_mode, nil),
      object_types: ed(assigns, :object_types, nil)
    }
  end

  def activity_with_object_from_assigns(%{activity: %{object: %{id: _}} = activity} = _assigns) do
    activity
  end

  def activity_with_object_from_assigns(
        %{activity: %{} = activity, object: %{id: _} = object} = _assigns
      ) do
    debug("Activity with both an activity and object")

    Map.put(
      activity,
      :object,
      object
    )
  end

  def activity_with_object_from_assigns(%{activity: %{} = activity} = assigns) do
    debug("Activity without :object as assoc")

    Activities.object_under_activity(activity, assigns[:object])
  end

  def activity_with_object_from_assigns(%{object: %{} = _object} = assigns) do
    debug("Activity with only an object")

    e(assigns[:object], :activity, nil) ||
      %Activity{
        subject:
          e(assigns[:object], :created, :creator, nil) || e(assigns[:object], :creator, nil),
        object: assigns[:object]
      }
  end

  def activity_with_object_from_assigns(_), do: nil

  def prepare_filters_assigns_preloads_posloads(filters, opts \\ []) do
    with {:ok, preset, filters} <- FeedLoader.prepare_feed_preset_and_filters(filters, opts) do
      {preload, postload} = activity_preloads_tuple_from_filters(filters, opts)

      {filters, debug(preset[:assigns] || [], "assssss"), preload, postload}
    end
  end

  def activity_preloads_tuple_from_filters(filters, opts \\ []) do
    # TODO: should we first pass the feed_name through the preset fetcher?
    preload = opts[:preload] || FeedLoader.contextual_preloads_from_filters(filters, :query)

    postload =
      opts[:postload] ||
        FeedLoader.contextual_preloads_from_filters(filters, :post)
        |> FeedLoader.filter_already_preloaded(preload)

    {preload, postload}
    |> debug()
  end

  def feed_extra_preloads_list(showing_within, thread_mode \\ nil) do
    # TODO: entirely replace with filter-based preloads?
    case {showing_within, thread_mode} do
      {:annotations, :flat} ->
        [:extra_info, :with_subject, :with_reply_to, :with_post_content]

      {:annotations, _} ->
        [:extra_info, :with_subject, :with_post_content]

      {:thread, :flat} ->
        [:feed, :with_reply_to, :with_media, :with_object_more, :maybe_with_labelled]

      {:thread, _} ->
        [:feed, :with_media, :with_object_more, :maybe_with_labelled]

      {:feed_by_creator, _} ->
        [:with_object_more, :feed_postload, :post_content]

      {:feed_by_subject, _} ->
        [:feed_by_subject, :feed_postload, :post_content]

      {:media, _} ->
        [:per_media, :with_creator, :with_post_content]

      _ ->
        [:feed_by_subject, :feed_postload, :post_content]
    end
    |> debug("whatpreloads")
  end

  # def feed_async_preloads_list(showing_within, thread_mode \\ nil) do
  #   feed_extra_preloads_list(showing_within, thread_mode)
  # end

  @decorate time()
  defp preload_extras(list_of_components, _list_of_ids, current_user) do
    # TODO: optimise the following so we don't iterate over all component assigns X times
    showing_within =
      list_of_components
      |> uniq_assign(:showing_within)
      |> debug("preloadwithin")

    thread_mode =
      list_of_components
      |> uniq_assign(:thread_mode)
      |> debug("thread_mode")

    activity_preloads =
      list_of_components
      |> uniq_assign(:activity_preloads) || {nil, nil}

    # |> Enums.filter_empty(nil) || #feed_async_preloads_list(showing_within, thread_mode)

    postloads =
      (elem(activity_preloads, 1) || [])
      |> debug("many_activity_postloads")

    opts = [
      preload: postloads,
      assign_activity_preloads: {(elem(activity_preloads, 0) || []) ++ postloads, []},
      with_cache: false,
      current_user: current_user,
      # skip boupreloadsndary because it should already be checked it the initial query
      skip_boundary_check: true
    ]

    # TODO skip if no postloads to load
    do_preload_extras(
      list_of_components,
      opts
    )
  end

  defp do_preload_extras(list_of_components, opts) do
    # NOTE: we receive the `ActivityLive` assigns pre-prepare even though this is running async

    activities =
      list_of_components
      |> debug("list_of_components")
      |> Enum.map(fn
        %{activity: %{__struct__: _} = activity} ->
          # debug(activity, "struct")
          activity

        %{activity: %{id: _} = activity} ->
          struct(Activity, activity)

        %{object: %{__struct__: _} = object} ->
          %Activity{object: object}

        %{activity: nil} ->
          nil

        other ->
          warn(other, "cannot preload extras")
          nil
      end)
      |> filter_empty([])
      # |> debug("list_of_activities pre-postload")
      |> preload_activity_and_object_assocs([:object], opts)

    list_of_activities =
      activities
      |> Map.new(fn activity -> {id(activity) || id(e(activity, :object, nil)), activity} end)
      |> debug("list_of_activities postloaded")

    list_of_emoji =
      activities
      |> Enum.map(fn a -> e(a, :edge, nil) end)
      |> Enums.filter_empty([])
      |> repo().maybe_preload(:emoji, skip_boundary_check: true)
      |> Map.new(fn edge ->
        case e(edge, :emoji, nil) do
          nil -> nil
          emoji -> {id(edge), emoji}
        end
      end)

    list_of_components
    # |> debug()
    |> Map.new(fn component ->
      activity = list_of_activities[component.object_id] || component.activity

      {
        component.component_id,
        if(activity,
          do: %{
            activity: activity,
            emoji: list_of_emoji[component.object_id],
            activity_preloads: opts[:assign_activity_preloads]
          }
        )
        # ActivityLive.assigns_from_activity(list_of_activities[component.object_id] || component.activity)
      }
    end)
  end

  # @decorate time()
  # def preloads(feed, socket_or_opts \\ [])

  # def preloads(feed, socket_or_opts) when is_list(feed) and feed != [] do
  #   opts = e(socket_or_opts, :assigns, nil) || socket_or_opts

  #   preloads = e(opts, :preload, :feed)
  #   debug(preloads, "Feed: preload assocs")

  #   opts = [
  #     preload: preloads,
  #     with_cache: e(opts, :with_cache, false),
  #     current_user: current_user(opts) || current_user(feed),
  #     # skip boundary because it should already be check it the initial query
  #     skip_boundary_check: true
  #   ]

  #   case feed do
  #     # Edges (eg. likes, follows)
  #     [%{edge: %{id: _}} | _] ->
  #       feed
  #       |> preload_activity_and_object_assocs([:edge, :object], opts)

  #     # Feed with activities
  #     [%{activity: %{id: _}} | _] ->
  #       feed
  #       |> preload_activity_and_object_assocs([:activity, :object], opts)

  #     # Objects without activity
  #     [%{object: %{id: _}} | _] ->
  #       feed
  #       |> preload_activity_and_object_assocs([:object], opts)

  #     _ ->
  #       warn("Could not preload activities - feed data structure was not recognised")
  #       debug(feed)
  #       feed
  #   end
  # end

  # def preloads(%{edges: feed} = page, socket),
  #   do: Map.put(page, :edges, preloads(feed, socket))

  # def preloads(feed, socket) do
  #   warn("Could not preload activities - provided data structure was not recognised")
  #   debug(feed)
  #   feed
  # end

  def preload_activity_and_object_assocs(feed, under, opts) do
    if Bonfire.Common.Config.get([:ui, :feed_object_extension_preloads_disabled]) != true do
      feed
      |> Bonfire.Social.Activities.activity_preloads(opts[:preload], opts)
      # |> debug("pre-maybe_preloads_per_nested_schema")
      |> Bonfire.Common.Repo.Preload.maybe_preloads_per_nested_schema(
        under,
        object_preloads(),
        opts
      )
    else
      feed
      |> Bonfire.Social.Activities.activity_preloads(opts[:preload], opts)
    end
  end

  # def preload_single_activity_and_object_assocs(feed, opts) do
  #   if Bonfire.Common.Config.get([:ui, :feed_object_extension_preloads_disabled]) != true do
  #     feed
  #     |> Bonfire.Social.Activities.activity_preloads(opts[:preload], opts)
  #     # |> debug("pre-maybe_preloads_per_nested_schema")
  #     |> Bonfire.Common.Repo.Preload.maybe_preloads_per_schema(
  #       object_preloads(),
  #       opts
  #     )
  #   else
  #     feed
  #     |> Bonfire.Social.Activities.activity_preloads(opts[:preload], opts)
  #   end
  # end

  def object_preloads do
    # TODO: collect these from the code/config on startup, same as how we pick what preview component to use
    [
      # {Bonfire.Data.Social.Post, Bonfire.UI.Social.Activity.NoteLive.preloads()}, # only needed if we no longer preload the post_content by default
      {Bonfire.Poll.Question,
       Utils.maybe_apply(Bonfire.Poll.Web.Preview.QuestionLive, :preloads)},
      {Bonfire.Data.Identity.User,
       Utils.maybe_apply(Bonfire.UI.Me.Preview.CharacterLive, :preloads, [])},
      {Bonfire.Classify.Category,
       Utils.maybe_apply(Bonfire.Classify.Web.Preview.CategoryLive, :preloads, [])},
      {ValueFlows.EconomicEvent,
       Utils.maybe_apply(Bonfire.UI.ValueFlows.Preview.EconomicEventLive, :preloads, [])},
      {ValueFlows.EconomicResource,
       Utils.maybe_apply(Bonfire.UI.ValueFlows.Preview.EconomicResourceLive, :preloads, [])},
      {ValueFlows.Planning.Intent,
       Utils.maybe_apply(Bonfire.UI.ValueFlows.Preview.IntentTaskLive, :preloads, [])},
      {ValueFlows.Process,
       Utils.maybe_apply(Bonfire.UI.ValueFlows.Preview.ProcessListLive, :preloads, [])}
    ]
    |> debug("preload object data in feed")
  end

  defp merge_feed_assigns(feed, new_assigns, previous_page_info) do
    {e(feed, :edges, []),
     new_assigns ++
       [
         previous_page_info: previous_page_info,
         page_info: e(feed, :page_info, [])
       ]}
  end

  # def user_feed_assign_or_load_async(
  #       tab,
  #       user_or_feed,
  #       params,
  #       %Phoenix.LiveView.Socket{} = socket
  #     ) do
  #   socket_connected = socket_connected?(socket)

  #   user = user_or_feed || e(assigns(socket), :user, nil) || current_user(assigns(socket))

  #   feed_id = e(user, :character, :outbox_id, nil) || id(user)

  #   feed_component_id =
  #     e(assigns(socket), :feed_component_id, nil) ||
  #       ComponentID.new(Bonfire.UI.Social.FeedLive, feed_id)

  #   if (socket_connected || not is_nil(current_user_id(assigns(socket)))) && Config.env() != :test do
  #     if socket_connected do
  #       debug(tab, "socket connected, so load async")
  #       pid = self()

  #       apply_task(:start_async, fn ->
  #         debug("Query user activities asynchronously")

  #         load_user_feed_assigns(tab, user_or_feed, params, socket)
  #         |> send_feed_updates(
  #           pid,
  #           # "feed_profile_#{tab}",
  #           feed_component_id,
  #           ...,
  #           Bonfire.UI.Social.FeedLive
  #         )
  #       end)
  #     else
  #       debug(tab, "socket NOT connected, but logged in, so no need to load for SEO")
  #     end

  #     # return temporary assigns in the meantime
  #     {:noreply,
  #      assign(socket,
  #        loading: true,
  #        feed_component_id: feed_component_id,
  #        feed_ids: [feed_id],
  #        feed: [],
  #        selected_tab: tab
  #      )}
  #   else
  #     debug(tab, "socket not connected or not logged in, just load feed")
  #     # for dead mounts
  #     {:noreply,
  #      assign_feed(
  #        socket,
  #        load_user_feed_assigns(tab, user_or_feed, params, socket)
  #      )}
  #   end
  # end

  # def user_feed_assign_or_load_async(tab, user_or_feed, params, socket) do
  #   debug(tab, "not a socket, just load feed")

  #   {:noreply,
  #    assign_feed(
  #      socket,
  #      load_user_feed_assigns(tab, user_or_feed, params, socket)
  #    )}
  # end

  # # note the 3 arity
  # def load_user_feed_assigns(selected_tab_and_user_id, params, socket) do
  #   with [selected_tab, user_id] <- String.split(selected_tab_and_user_id, "_") do
  #     debug(params, "Load and maybe paginate feed for user: #{selected_tab_and_user_id}")
  #     load_user_feed_assigns(selected_tab, user_id, params, socket)
  #   end
  # end

  # # note the 4 arity
  # def load_user_feed_assigns(
  #       tab,
  #       feed_id,
  #       attrs,
  #       %{assigns: %{feed_filters: feed_filters}} = socket
  #     )
  #     when not is_nil(feed_filters) and feed_filters != [] do
  #   params = input_to_atoms(attrs)

  #   # for custom feeds
  #   feed_id =
  #     uid!(feed_id)

  #   # preloads = activity_preloads_tuple_from_filters(e(assigns(socket), :showing_within, nil))
  #   {preloads, postloads} =
  #     activity_preloads_tuple_from_filters(feed_filters,
  #       showing_within: e(assigns(socket), :showing_within, nil)
  #     )

  #   feed =
  #     if module = maybe_module(FeedLoader, socket),
  #       do:
  #         module.feed(
  #           feed_id,
  #           feed_filters,
  #           pagination: params,
  #           exclude_feed_ids: e(params, :exclude_feed_ids, []),
  #           current_user: current_user(assigns(socket)),
  #           preload: preloads
  #         ),
  #       else: []

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       feed_update_mode: "append",
  #       loading: false,
  #       selected_tab: tab,
  #       feed_id: feed_id,
  #       activity_preloads: {preloads, postloads}
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  # # note the 4 arity
  # def load_user_feed_assigns("posts" = tab, user, params, socket) do
  #   user = user || e(assigns(socket), :user, nil)
  #   showing_within = :feed_by_creator
  #   current_user = current_user(assigns(socket))
  #   filters = e(assigns(socket), :filters, %{})
  #   # preloads = [:feed_by_creator] ++ activity_preloads_tuple_from_filters(showing_within)
  #   {preloads, postloads} =
  #     activity_preloads_tuple_from_filters(filters,
  #       showing_within: e(assigns(socket), :showing_within, nil)
  #     )

  #   #  TODO: use FeedLoader
  #   feed =
  #     Utils.maybe_apply(
  #       Bonfire.Posts,
  #       :list_by,
  #       [
  #         user,
  #         [
  #           pagination: input_to_atoms(params),
  #           current_user: current_user,
  #           preload: preloads
  #         ]
  #       ],
  #       current_user: current_user,
  #       fallback_return: []
  #     )

  #   # |> debug("posts")

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       loading: false,
  #       selected_tab: tab,
  #       page: "posts",
  #       showing_within: showing_within,
  #       activity_preloads: {preloads, postloads}
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  # def load_user_feed_assigns("objects" = tab, user, %{"extra" => type} = params, socket) do
  #   user = user || e(assigns(socket), :user, nil)
  #   current_user = current_user(assigns(socket))
  #   type = Types.maybe_to_atom(type)
  #   object_types = Types.maybe_to_module(type) || type
  #   filters = e(assigns(socket), :filters, %{})
  #   # preloads = [:feed_by_creator] ++ activity_preloads_tuple_from_filters(:feed_by_creator)
  #   {preloads, postloads} =
  #     activity_preloads_tuple_from_filters(filters,
  #       showing_within: e(assigns(socket), :showing_within, nil)
  #     )

  #   feed_id =
  #     if not is_nil(user),
  #       do:
  #         maybe_apply(Bonfire.Social.Feeds, :feed_id, [:outbox, user],
  #           current_user: current_user,
  #           fallback_return: nil
  #         )
  #         |> debug("outbox for #{id(user)}")

  #   feed =
  #     if not is_nil(feed_id),
  #       do:
  #         maybe_apply(
  #           FeedLoader,
  #           :feed,
  #           [
  #             feed_id,
  #             %{filters | object_types: object_types},
  #             [
  #               pagination: input_to_atoms(params),
  #               current_user: current_user(assigns(socket)),
  #               subject_user: user,
  #               showing_within: type,
  #               preload: preloads
  #             ]
  #           ],
  #           current_user: current_user,
  #           fallback_return: []
  #         ),
  #       else: []

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       loading: false,
  #       selected_tab: tab,
  #       page: "objects",
  #       showing_within: type,
  #       activity_preloads: {preloads, postloads}
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  # def load_user_feed_assigns("boosts" = tab, user, params, socket) do
  #   user = user || e(assigns(socket), :user, nil)
  #   current_user = current_user(assigns(socket))

  #   #  TODO: use FeedLoader
  #   feed =
  #     maybe_apply(
  #       Bonfire.Social.Boosts,
  #       :list_by,
  #       [user, [pagination: input_to_atoms(params), current_user: current_user]],
  #       current_user: current_user,
  #       fallback_return: []
  #     )

  #   # |> debug("boosts")

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       loading: false,
  #       selected_tab: tab,
  #       showing_within: :feed_by_subject
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  # def load_user_feed_assigns("timeline" = tab, user, params, socket) do
  #   user = user || e(assigns(socket), :user, nil)
  #   filters = e(assigns(socket), :filters, %{})

  #   {preloads, postloads} =
  #     activity_preloads_tuple_from_filters(filters,
  #       showing_within: e(assigns(socket), :showing_within, nil)
  #     )

  #   current_user = current_user(assigns(socket))

  #   feed_id =
  #     if not is_nil(user),
  #       do:
  #         maybe_apply(Bonfire.Social.Feeds, :feed_id, [:outbox, user],
  #           current_user: current_user,
  #           fallback_return: nil
  #         )
  #         |> debug("outbox for #{id(user)}")

  #   feed =
  #     if not is_nil(feed_id),
  #       do:
  #         maybe_apply(
  #           FeedLoader,
  #           :feed,
  #           [
  #             feed_id,
  #             filters,
  #             [
  #               pagination: input_to_atoms(params),
  #               current_user: current_user(assigns(socket)),
  #               subject_user: user,
  #               preload: preloads
  #             ]
  #           ],
  #           current_user: current_user,
  #           fallback_return: []
  #         ),
  #       else: []

  #   #  debug(feed: feed)

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       loading: false,
  #       selected_tab: tab,
  #       showing_within: :feed_by_subject,
  #       feed_id: feed_id,
  #       activity_preloads: {preloads, postloads}
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  # def load_user_feed_assigns(tab, feed_id, attrs, socket)
  #     when is_binary(tab) and is_binary(feed_id) do
  #   params = input_to_atoms(attrs)
  #   current_user = current_user(assigns(socket))
  #   filters = e(assigns(socket), :filters, %{})
  #   # for custom feeds
  #   feed_id =
  #     uid!(feed_id)
  #     |> debug("feed_id")

  #   {preloads, postloads} =
  #     activity_preloads_tuple_from_filters(filters,
  #       showing_within: e(assigns(socket), :showing_within, nil)
  #     )

  #   feed =
  #     maybe_apply(
  #       FeedLoader,
  #       :feed,
  #       [
  #         feed_id,
  #         filters,
  #         [
  #           pagination: params,
  #           exclude_feed_ids: e(params, :exclude_feed_ids, []),
  #           current_user: current_user,
  #           preload: preloads
  #         ]
  #       ],
  #       current_user: current_user,
  #       fallback_return: []
  #     )
  #     |> debug("feed")

  #   merge_feed_assigns(
  #     feed,
  #     [
  #       loading: false,
  #       selected_tab: tab,
  #       feed_id: feed_id,
  #       activity_preloads: {preloads, postloads}
  #     ],
  #     e(assigns(socket), :page_info, nil)
  #   )
  # end

  def handle_event("preset_create", %{"name" => name} = params, socket) do
    debug(params)

    with %{} = filters <- e(assigns(socket), :feed_filters, nil) || error("no filters"),
         {:ok, settings} <-
           Bonfire.Common.Settings.put(
             [:bonfire_social, Bonfire.Social.Feeds, :feed_presets, maybe_to_atom(name)],
             %{
               name: name,
               description: params["description"],
               icon: "ph:rss-simple-bold",
               exclude_from_nav: params["show_in_nav"] != "on",
               filters: filters
             },
             current_user: current_user(socket)
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end

  def handle_event("preset_delete", %{"id" => id} = params, socket) do
    debug(params)

    with {:ok, settings} <-
           Bonfire.Common.Settings.delete(
             [:bonfire_social, Bonfire.Social.Feeds, :feed_presets, maybe_to_atom(id)],
             current_user: current_user(socket)
           ) do
      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end

  def handle_event("preset_nav_toggle", %{"id" => id, "exclude" => exclude} = params, socket) do
    debug(exclude, "preset_nav_toggle params")

    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             [
               :bonfire_social,
               Bonfire.Social.Feeds,
               :feed_presets,
               maybe_to_atom(id),
               :exclude_from_nav
             ],
             exclude,
             current_user: current_user(socket)
           ) do
      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end

  def handle_event("toggle_feeds_nav_visibility", _params, socket) do
    debug("toggle_feeds_nav_visibility")

    with {:ok, settings} <-
           Bonfire.Common.Settings.set(
             %{
               Bonfire.Social.FeedLive => %{
                 show_feeds_nav_open:
                   !Bonfire.Common.Settings.get(
                     [Bonfire.Social.FeedLive, :show_feeds_nav_open],
                     true,
                     socket
                   )
               }
             },
             current_user: current_user(socket)
           ) do
      {
        :noreply,
        socket |> maybe_assign_context(settings)
      }
    end
  end
end
