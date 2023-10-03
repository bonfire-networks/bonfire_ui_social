defmodule Bonfire.Social.Feeds.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  use Untangle
  alias Bonfire.Social.Activities
  alias Bonfire.Data.Social.Activity
  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.FeedActivities

  def handle_params(
        %{"after" => _cursor_after} = attrs,
        _,
        socket
      ) do
    paginate_feed(
      e(socket.assigns, :feed_name, nil) || e(socket.assigns, :feed_id, nil) ||
        e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :id, nil),
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
      e(socket.assigns, :feed_name, nil) || e(socket.assigns, :feed_id, nil) ||
        e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :id, nil),
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
      e(socket.assigns, :feed_name, nil) || e(socket.assigns, :feed_id, nil) ||
        e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :id, nil),
      attrs,
      socket,
      hide_activities: "infinite_scroll"
    )
  end

  def handle_event("reply_to_activity", _params, socket) do
    activity = e(socket.assigns, :activity, %{})

    Bonfire.Social.Threads.LiveHandler.reply(
      e(socket.assigns, :object, nil) ||
        e(activity, :object, nil) ||
        e(socket.assigns, :object_id, nil) ||
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
    current_user = current_user(socket.assigns)
    activity = e(socket.assigns, :activity, nil) || id(params)
    object = e(socket.assigns, :object, nil) || activity

    to =
      case to do
        "instance_moderators" -> [notifications: Bonfire.Social.Flags.instance_moderators()]
        # TODO
        to -> to
      end
      |> FeedActivities.get_feed_ids()
      |> debug("tooo")

    # TODO: check permission
    with {:ok, _} <-
           FeedActivities.maybe_feed_publish(current_user, activity, object, to,
             current_user: current_user
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Done!"))}
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
        apply_task(:start_link, fn ->
          # asynchronously simply so the count is updated quicker for the user
          debug(activity_id, "mark_seen")
          Bonfire.Social.Seen.mark_seen(current_user, activity_id)
        end)

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

    maybe_send_update(Bonfire.UI.Common.BadgeCounterLive, feed_ids, count_increment: 1)

    {:noreply, socket}
  end

  def handle_info({:new_activity, data}, socket) do
    debug(data[:feed_ids], "received new_activity for these feed ids")
    # dump(data)
    current_user = current_user(socket.assigns)

    permitted? =
      Bonfire.Common.Pointers.exists?([id: e(data, :activity, :object, :id, nil)],
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
    remove_activity(activity)

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

  def reply_to_activity(js \\ %JS{}, activity_component_id) do
    js
    |> JS.push(
      "Bonfire.Social.Feeds:reply_to_activity",
      target: "##{activity_component_id}"
    )
    |> Bonfire.UI.Common.SmartInput.LiveHandler.maximize()
  end

  defp send_feed_updates(pid \\ nil, feed_ids, assigns, component \\ Bonfire.UI.Social.FeedLive)

  defp send_feed_updates(pid, feed_ids, {entries, assigns}, component) when is_list(assigns) do
    send_feed_updates(pid, feed_ids, assigns ++ [insert_stream: %{feed: entries}], component)
  end

  defp send_feed_updates(pid, feed_id, assigns, component)
       when (is_pid(pid) or is_nil(pid)) and (is_list(assigns) or is_map(assigns)) do
    debug(feed_id, "Sending feed update to")
    maybe_send_update(pid, component, feed_id, assigns)
  end

  defp send_feed_updates(pid, feed_id, {:error, e}, _component) do
    debug(feed_id, "Returning error instead of feed")
    assign_error(%{}, e, pid)
  end

  def paginate_feed(feed_id, attrs, socket, opts \\ [])

  def paginate_feed("user_" <> selected_tab_and_user_id, attrs, socket, _opts) do
    debug(selected_tab_and_user_id, "paginate user feed")

    {:noreply,
     socket
     |> insert_feed(load_user_feed_assigns(selected_tab_and_user_id, attrs, socket))}
  end

  def paginate_feed(feed_id, attrs, socket, opts) do
    opts = paginate_opts(attrs, socket, opts)

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
    # |> debug("Feeds - paginate - a feed_id has been assigned in the view, so load that")
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
      |> Keyword.put(:time_limit, attrs[:time_limit] || e(socket.assigns, :time_limit, nil))

    opts
    |> Keyword.put(
      :paginate,
      Keyword.merge(
        Keyword.new(attrs),
        Activities.order_pagination_opts(
          opts[:sort_by] || e(socket.assigns, :sort_by, nil),
          opts[:sort_order] || e(socket.assigns, :sort_order, nil)
        )
      )
    )
  end

  def paginate_fetch_assign_default(opts, socket) do
    debug(opts)

    # || current_account(socket)
    current = current_user(socket.assigns)

    feed_or_tuple =
      if current do
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

  defp paginate_fetch_assign_feed(:likes, _opts, socket) do
    warn("TODO")
    {:noreply, socket}
  end

  defp paginate_fetch_assign_feed(feed_id, opts, socket) do
    feed = FeedActivities.feed(feed_id, opts)

    {:noreply,
     socket
     |> assign_generic(
       feed_update_mode: "append",
       hide_activities: opts[:hide_activities],
       feed_count: Enum.count(e(feed, :edges, [])),
       time_limit: opts[:time_limit],
       previous_page_info: e(socket.assigns, :page_info, false),
       page_info: e(feed, :page_info, [])
     )
     |> insert_feed(e(feed, :edges, []), opts)}
  end

  def insert_feed(socket, feed_edges, opts \\ [])

  def insert_feed(socket, {[], assigns}, _opts) do
    debug(assigns, "nothing to add")

    socket
    |> assign_generic(
      previous_page_info: e(socket.assigns, :page_info, false),
      page_info: assigns[:page_info],
      loading: false
    )

    # |> assign_generic(assigns)
  end

  def insert_feed(socket, {:error, assigns}, _opts) do
    socket
    |> assign_error(assigns)
  end

  def insert_feed(socket, {feed_edges, assigns}, opts) do
    socket
    |> assign_generic(assigns)
    |> insert_feed(feed_edges, opts)
  end

  def insert_feed(socket, feed_edges, opts) do
    # socket
    # |> assign_generic(feed: feed_edges)

    if e(feed_edges, :feed_component_id, nil) do
      # temp workaround for when we're not actually getting a feed but rather a list of assigns for some reason
      socket
      |> assign_generic(feed_edges)
    else
      # debug(feed_edges, "insert feed into stream")
      maybe_stream_insert(socket, :feed, feed_edges || [], opts)
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

  defp feed_filter_assigns(%{"object_type" => "discussions" = filter}),
    do: [
      tab_path_suffix: "/#{filter}",
      page_title: l("Discussions"),
      page_header_icon: "ri:discuss-line"
    ]

  defp feed_filter_assigns(%{"object_type" => "posts" = filter}),
    do: [
      tab_path_suffix: "/#{filter}",
      page_title: l("Posts"),
      page: "posts",
      page_header_icon: "ri:chat-2-line"
    ]

  defp feed_filter_assigns(_),
    do: [tab_path_suffix: nil, page_title: l("Activities"), page_header_icon: "ri:home-line"]

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
      |> debug()
      |> FeedActivities.feed_name(current_user_id(socket))
      |> debug()

    debug(filters_or_custom_query_or_feed_id_or_ids, feed_name)

    assigns =
      (feed_default_assigns(feed_name, socket) ++
         feed_filter_assigns(filters_or_custom_query_or_feed_id_or_ids) ++ [loading: show_loader])
      |> debug("start by setting feed_default_assigns")

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
      |> debug()
      |> FeedActivities.feed_name(current_user_id(socket))
      |> debug()

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
  #       {Bonfire.UI.Social.FeedControlsLive,
  #        [
  #          event_target: component_id,
  #          sort_by: e(socket, :assigns, :sort_by, nil),
  #          time_limit: e(socket, :assigns, :sort_by, 7),
  #          sort_order: e(socket, :assigns, :sort_order, false)
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

    component_id = component_id(feed_id, socket.assigns)

    [
      feed_name: feed_name,
      feed_id: feed_id,
      feed_ids: feed_ids,
      feed_component_id: component_id,
      # FIXME: clean up page vs tab
      selected_tab: nil,
      page: "feed",
      # page_title: l("My feed"),
      # feed_title: l("My feed"),
      feed: nil,
      page_info: nil
    ]

    # ] ++ page_header_asides(socket, component_id)
  end

  def feed_default_assigns(:explore = feed_name, socket) do
    feed_id = :explore

    component_id = component_id(feed_id, socket.assigns)

    [
      feed_name: feed_name,
      feed_id: :explore,
      feed_component_id: component_id,
      selected_tab: :explore,
      # FIXME: clean up page vs tab
      page: "explore",
      page_title: "Explore activities",
      no_header: false,
      # page_title: l("Activities from members of the local instance"),
      feedback_title: l("There is not activities to explore"),
      # feed_id: feed_name,
      feedback_message:
        l("It seems like the paint is still fresh and there are no activities to explore..."),
      feed: nil,
      page_info: nil
    ]

    # ] ++ page_header_asides(socket, component_id)
  end

  def feed_default_assigns(:fediverse = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:activity_pub)
      |> debug(feed_name)

    component_id = component_id(feed_id, socket.assigns)

    [
      feed_name: feed_name,
      feed_id: feed_id,
      feed_component_id: component_id,
      selected_tab: :fediverse,
      # FIXME: clean up page vs tab
      page: "federation",
      page_title: "Explore remote activities from the fediverse",
      no_header: false,
      # page_header_icon: "ri:home-line",
      # page_title: l("Federated activities from remote instances"),
      # feed_title: l("Activities from around the fediverse"),
      feedback_title: l("Your fediverse feed is empty"),
      feedback_message:
        l(
          "It seems you and other local users do not follow anyone on a different federated instance"
        ),
      # feed_id: feed_name,
      feed: nil,
      page_info: nil
    ]

    # ] ++ page_header_asides(socket, component_id)
  end

  def feed_default_assigns(:local = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:local)
      |> debug(feed_name)

    component_id = component_id(feed_id, socket.assigns)

    [
      feed_name: feed_name,
      feed_id: feed_id,
      feed_component_id: component_id,
      selected_tab: :local,
      # FIXME: clean up page vs tab
      page: "local",
      page_title: "Explore activities local to this instance",
      no_header: false,
      # page_title: l("Activities from members of the local instance"),
      feedback_title: l("Your local feed is empty"),
      # feed_id: feed_name,
      feedback_message: l("It seems like the paint is still fresh on this instance..."),
      feed: nil,
      page_info: nil
    ]

    # ] ++ page_header_asides(socket, component_id)
  end

  def feed_default_assigns(:likes = feed_name, socket) do
    # debug(feed_name)

    [
      feed_name: feed_name,
      feed_id: feed_name,
      feed_component_id: component_id(feed_name, socket.assigns),
      selected_tab: :likes,
      hide_tabs: true,
      showing_within: :feed_by_subject,
      # FIXME: clean up page vs tab
      page: "favourites",
      page_title: "Favourites",
      no_header: false,
      # page_title: l("My favourites"),
      # feed_title: l("My favourites"),
      feedback_title: l("You have no favourites yet"),
      # feed_id: feed_name,
      # feedback_message: l("It seems like the paint is still fresh on this instance..."),
      feed: nil,
      page_info: nil
    ]
  end

  # WIP
  def feed_default_assigns(:flags = feed_name, socket) do
    [
      feed_name: feed_name,
      feed_id: feed_name,
      feed_component_id: component_id(feed_name, socket.assigns),
      selected_tab: :flags,
      scope: :instance,
      # FIXME: clean up page vs tab
      page: "flags",
      # page_title: l("My favourites"),
      # feed_title: l("My favourites"),
      feedback_title: l("You have no flagged activities..."),
      # feed_id: feed_name,
      # feedback_message: l("It seems like the paint is still fresh on this instance..."),
      feed: nil,
      page_info: nil
    ]
  end

  def feed_default_assigns({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket)
      when is_atom(feed_name) do
    debug(feed_name, "feed_name")
    debug(filters_or_custom_query_or_feed_id_or_ids, "filters_or_custom_query_or_feed_id_or_ids")

    feed_default_assigns(feed_name, socket) ++
      [
        # feed_name: feed_name,
        # feed_id: feed_name,
        feed_filters: filters_or_custom_query_or_feed_id_or_ids
        # feed_component_id: component_id(feed_name, socket.assigns),
        # feed: nil,
        # page_info: nil
      ]
  end

  def feed_default_assigns({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket)
      when is_binary(feed_name) do
    debug(feed_name, "feed_name")
    debug(filters_or_custom_query_or_feed_id_or_ids, "filters_or_custom_query_or_feed_id_or_ids")

    [
      feed_name: feed_name,
      feed_id: feed_name,
      feed_filters: filters_or_custom_query_or_feed_id_or_ids,
      feed_component_id: component_id(feed_name, socket.assigns),
      feed: nil,
      page_info: nil
    ]
  end

  def feed_default_assigns(:default, socket) do
    FeedActivities.feed_name(:default, current_user_id(socket))
    |> feed_default_assigns(socket)
  end

  def feed_default_assigns(feed_name, socket) when is_atom(feed_name) do
    debug(feed_name)

    [
      feed_name: feed_name,
      feed_id: feed_name,
      feed_component_id: component_id(feed_name, socket.assigns),
      feed: nil,
      page_info: nil
    ]
  end

  def feed_default_assigns(other, socket) do
    debug(other)

    [
      feed_component_id: component_id(other, socket.assigns),
      feed: nil,
      page_info: nil
    ]
  end

  defp component_id(feed_id_or_tuple, assigns),
    do:
      (e(assigns, :feed_component_id, nil) ||
         feed_id_or_tuple |> debug("feed_id_or_tuple") |> feed_id_only() || :feeds)
      |> debug("the_feed_component_id")

  # @decorate time()
  defp feed_assigns_maybe_async_load(
         feed_name_id_or_tuple,
         assigns,
         socket,
         reset_stream \\ false
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
    socket_connected = connected?(socket)

    if (socket_connected || current_user(socket.assigns)) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load feed async")
        pid = self()

        apply_task(:start_link, fn ->
          debug(feed_name_id_or_tuple, "Query activities asynchronously")

          {entries, new_assigns} = feed_assigns(feed_name_id_or_tuple, socket)
          # |> debug("feed_assigns")

          send_feed_updates(
            pid,
            assigns[:feed_component_id] || :feeds,
            {entries,
             new_assigns ++
               [
                 loaded_async: true,
                 reset_stream: reset_stream
               ]},
            Bonfire.UI.Social.FeedLive
          )
        end)
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      # return temporary assigns in the meantime
      assigns
    else
      debug("socket not connected or not logged in, load feed synchronously")

      feed_assigns_merged(feed_name_id_or_tuple, assigns, socket)
    end
  end

  defp feed_assigns_maybe_async_load(feed_name_id_or_tuple, assigns, socket, _reset_stream) do
    feed_assigns_merged(feed_name_id_or_tuple, assigns, socket)
  end

  defp feed_assigns_merged(feed_id, assigns, socket) do
    case feed_assigns(feed_id, socket) do
      {entries, feed_assigns} when is_list(feed_assigns) -> {entries, assigns ++ feed_assigns}
      e -> e
    end
  end

  defp feed_id_only({feed_id, _feed_ids}), do: feed_id
  defp feed_id_only(feed_id), do: feed_id

  @decorate time()
  defp feed_assigns(feed, socket)

  defp feed_assigns({:likes, _filters}, socket) do
    # NOTE: we don't support extra filter on likes for now
    feed_assigns(:likes, socket)
  end

  defp feed_assigns({feed_id, feed_id_or_ids}, socket)
       when feed_id == :my or (is_list(feed_id_or_ids) and feed_id_or_ids != []) do
    # My Feed
    with %{} = feed <-
           feed_id_or_ids
           |> debug("feed_id_or_ids")
           |> FeedActivities.my_feed(socket, ...) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns({{feed_id, nil}, %{} = filters}, socket) when filters != %{} do
    # clean up
    with %{} = feed <-
           {feed_id, filters}
           |> debug("filters")
           |> FeedActivities.feed(socket) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns({feed_id, %{} = filters}, socket) when filters != %{} do
    with %{} = feed <-
           {feed_id, filters}
           |> debug("filters")
           |> FeedActivities.feed(socket) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns(feed_id, socket) when is_binary(feed_id) do
    with %{} = feed <-
           feed_id
           |> debug("feed_id")
           |> FeedActivities.feed(..., socket) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns(:likes = _feed_id, socket) do
    # TODO: pagination
    with %{} = feed <-
           Bonfire.Social.Likes.list_my(current_user: current_user_required!(socket)) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns(%Ecto.Query{} = custom_query, socket) do
    with %{} = feed <-
           custom_query
           |> debug("custom_query")
           |> FeedActivities.feed(socket) do
      merge_feed_assigns(feed, [loading: false], e(socket.assigns, :page_info, nil))
    end
  end

  defp feed_assigns(feed_name, socket) when is_atom(feed_name) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(feed_name, socket)

    with %{} = feed <-
           FeedActivities.feed({feed_name, feed_id}, socket) do
      merge_feed_assigns(
        feed,
        [
          loading: false,
          feed_name: feed_name,
          feed_id: feed_id
        ],
        e(socket.assigns, :page_info, nil)
      )
    end
  end

  defp feed_assigns(feed_name, %{assigns: %{feed_filters: feed_filters}} = socket)
       when not is_nil(feed_filters) and feed_filters != [] do
    debug(feed_filters, "use feed_filters")
    feed_assigns({feed_name, feed_filters}, socket)
  end

  defp feed_assigns({feed_id, other}, socket) when is_atom(feed_id) and not is_nil(feed_id) do
    warn(other, "ignoring unsupported param, for feed #{inspect(feed_id)}")
    feed_assigns(feed_id, socket)
  end

  defp feed_assigns({"user_" <> tab_and_user_or_other_id, other}, socket) do
    debug(other, "load user/other timeline: #{tab_and_user_or_other_id}")

    [tab, user_or_other_id] = String.split(tab_and_user_or_other_id, "_", parts: 2)

    load_user_feed_assigns(tab, user_or_other_id, other, socket)
    # |> debug()
  end

  defp feed_assigns({feed_id, other}, socket) do
    warn(feed_id, "unrecognised feed_id")
    warn(other, "unrecognised param")
    feed_assigns(feed_id || other, socket)
  end

  defp feed_assigns(feed_id, _socket) do
    error(feed_id, "Unrecognised feed")
  end

  def preload(list_of_assigns, opts) do
    list_of_assigns
    |> Bonfire.Boundaries.LiveHandler.maybe_preload_and_check_boundaries(opts ++ [verbs: [:read]])
    # |> preloads(opts) # NOTE: we preload most activity assocs after querying rather than here so as to not mix different ways they're loaded (eg. Edges vs FeedPublish)
    |> Enum.map(&Activities.assigns_with_object_under_activity/1)
    |> preload_assigns_async(
      &assigns_to_params/1,
      &preload_extras/3,
      opts ++ [preload_status_key: :preloaded_async_activities]
    )

    # |> debug
  end

  defp assigns_to_params(assigns) do
    activity = e(assigns, :activity, nil)
    object = e(assigns, :object, nil)

    %{
      component_id: assigns.id,
      activity: activity,
      object: object,
      object_id: id(activity) || id(object),
      showing_within: e(assigns, :showing_within, nil),
      thread_mode: e(assigns, :thread_mode, nil),
      object_type: e(assigns, :object_type, nil)
    }
  end

  defp uniq_assign(list_of_components, field) do
    case list_of_components
         |> Enum.map(& &1[field])
         |> Enum.uniq() do
      [nil] ->
        nil

      [val] ->
        val

      other ->
        warn(other, "more than one kind of #{field}")
        nil
    end
  end

  @decorate time()
  defp preload_extras(list_of_components, _list_of_ids, current_user) do
    # TODO: less preloads if not in a feed

    showing_within =
      list_of_components
      |> uniq_assign(:showing_within)
      |> debug("preloadwithin")

    thread_mode =
      list_of_components
      |> uniq_assign(:thread_mode)
      |> debug("thread_mode")

    preloads =
      case {showing_within, thread_mode} do
        {:thread, :flat} -> [:feed, :with_reply_to, :with_media, :with_object_more]
        {:thread, _} -> [:feed, :with_media, :with_object_more]
        {:feed_by_creator, _} -> [:with_object_more, :feed_postload]
        {:feed_by_subject, _} -> [:feed_by_subject, :feed_postload]
        _ -> [:feed_by_subject, :feed_postload]
      end
      |> debug("whatpreloads")

    opts = [
      preload: preloads,
      with_cache: false,
      current_user: current_user,
      # skip boundary because it should already be checked it the initial query
      skip_boundary_check: true
    ]

    # NOTE: we receive the `ActivityLive` assigns pre-prepare even though this is running async

    list_of_activities =
      list_of_components
      # |> debug("list_of_components")
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
      |> debug("list_of_activities pre-postload")
      |> preload_activity_and_object_assocs([:object], opts)
      |> Map.new(fn activity -> {id(activity) || id(e(activity, :object, nil)), activity} end)
      |> debug("list_of_activities postloaded")

    list_of_components
    # |> debug()
    |> Map.new(fn component ->
      {component.component_id,
       %{
         activity: list_of_activities[component.object_id] || component.activity
         # object_type: Types.object_type(list_of_activities[component.object_id]) || component.object_type
       }}
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

  def object_preloads do
    # TODO: collect these from the code on startup
    [
      # {Bonfire.Data.Social.Post, Bonfire.UI.Social.Activity.NoteLive.preloads()}, # only needed if we no longer preload PostContent by default
      {Bonfire.Data.Identity.User, Bonfire.UI.Social.Activity.CharacterLive.preloads()},
      {Bonfire.Classify.Category, Bonfire.UI.Social.Activity.CategoryLive.preloads()},
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()}
    ]
    |> debug("preload object data in feed")
  end

  def user_feed_assign_or_load_async(
        tab,
        user_or_feed,
        params,
        %Phoenix.LiveView.Socket{} = socket
      ) do
    socket_connected = connected?(socket)

    if (socket_connected || current_user(socket.assigns)) && Config.env() != :test do
      if socket_connected do
        debug(tab, "socket connected, so load async")
        pid = self()

        apply_task(:start_link, fn ->
          debug("Query user activities asynchronously")

          load_user_feed_assigns(tab, user_or_feed, params, socket)
          |> send_feed_updates(
            pid,
            "feed_profile_#{tab}",
            ...,
            Bonfire.UI.Social.FeedLive
          )
        end)
      else
        debug(tab, "socket NOT connected, but logged in, so no need to load for SEO")
      end

      # return temporary assigns in the meantime
      {:noreply,
       assign(socket,
         loading: true,
         feed: [],
         selected_tab: tab
       )}
    else
      debug(tab, "socket not connected or not logged in, just load feed")
      # for dead mounts
      {:noreply,
       assign_feed(
         socket,
         load_user_feed_assigns(tab, user_or_feed, params, socket)
       )}
    end
  end

  def user_feed_assign_or_load_async(tab, user_or_feed, params, socket) do
    debug(tab, "not a socket, just load feed")

    {:noreply,
     assign_feed(
       socket,
       load_user_feed_assigns(tab, user_or_feed, params, socket)
     )}
  end

  # note the 3 arity
  def load_user_feed_assigns(selected_tab_and_user_id, params, socket) do
    with [selected_tab, user_id] <- String.split(selected_tab_and_user_id, "_") do
      debug(params, "Load and maybe paginate feed for user: #{selected_tab_and_user_id}")
      load_user_feed_assigns(selected_tab, user_id, params, socket)
    end
  end

  # note the 4 arity
  def load_user_feed_assigns(
        tab,
        feed_id,
        attrs,
        %{assigns: %{feed_filters: feed_filters}} = socket
      )
      when not is_nil(feed_filters) and feed_filters != [] do
    params = input_to_atoms(attrs)

    # for custom feeds
    feed_id =
      ulid!(feed_id)
      |> debug("feed_id")

    feed =
      if module_enabled?(FeedActivities, socket),
        do:
          FeedActivities.feed({feed_id, feed_filters},
            pagination: params,
            exclude_feed_ids: e(params, :exclude_feed_ids, []),
            current_user: current_user(socket.assigns)
          )
          |> debug("feed")

    merge_feed_assigns(
      feed,
      [
        loading: false,
        selected_tab: tab,
        feed_id: feed_id
      ],
      e(socket.assigns, :page_info, nil)
    )
  end

  # note the 4 arity
  def load_user_feed_assigns("posts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed =
      if module_enabled?(Bonfire.Social.Posts, user),
        do:
          Bonfire.Social.Posts.list_by(user,
            pagination: input_to_atoms(params),
            current_user: current_user(socket.assigns),
            preload: :feed_by_creator
          )

    # |> debug("posts")

    merge_feed_assigns(
      feed,
      [
        loading: false,
        selected_tab: tab,
        page: "posts",
        showing_within: :feed_by_creator
      ],
      e(socket.assigns, :page_info, nil)
    )
  end

  def load_user_feed_assigns("boosts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed =
      if module_enabled?(Bonfire.Social.Boosts, user),
        do:
          Bonfire.Social.Boosts.list_by(user,
            pagination: input_to_atoms(params),
            current_user: current_user(socket.assigns)
          )

    # |> debug("boosts")

    merge_feed_assigns(
      feed,
      [
        loading: false,
        selected_tab: tab,
        showing_within: :feed_by_subject
      ],
      e(socket.assigns, :page_info, nil)
    )
  end

  def load_user_feed_assigns("timeline" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed_id =
      if user && module_enabled?(Bonfire.Social.Feeds, user),
        do:
          Bonfire.Social.Feeds.feed_id(:outbox, user)
          |> debug("outbox for #{id(user)}")

    feed =
      if feed_id && module_enabled?(FeedActivities, user),
        do:
          FeedActivities.feed(feed_id,
            pagination: input_to_atoms(params),
            current_user: current_user(socket.assigns),
            subject_user: user
          )

    #  debug(feed: feed)

    merge_feed_assigns(
      feed,
      [
        loading: false,
        selected_tab: tab,
        showing_within: :feed_by_subject,
        feed_id: feed_id
      ],
      e(socket.assigns, :page_info, nil)
    )
  end

  def load_user_feed_assigns(tab, user, params, socket) when tab in ["followers", "members"] do
    user = user || e(socket, :assigns, :user, nil)
    current_user = current_user(socket.assigns)
    pagination = input_to_atoms(params)

    requests =
      if id(user) == id(current_user), do: list_requests(current_user, pagination), else: []

    followers =
      Bonfire.Social.Follows.list_followers(user,
        pagination: pagination,
        current_user: current_user
      )
      |> debug("followers in feeed")

    [
      loading: false,
      back: "/@#{e(user, :character, :username, nil)}",
      selected_tab: tab,
      feed: requests ++ e(followers, :edges, []),
      page_info: e(followers, :page_info, []),
      previous_page_info: e(socket.assigns, :page_info, false)
    ]
  end

  def load_user_feed_assigns("followed" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    current_user = current_user(socket.assigns)
    pagination = input_to_atoms(params)

    requested =
      if id(user) == id(current_user), do: list_requested(current_user, pagination), else: []

    followed =
      Bonfire.Social.Follows.list_followed(user,
        pagination: pagination,
        current_user: current_user
      )

    # |> debug("followed")

    [
      loading: false,
      back: "/@#{e(user, :character, :username, nil)}",
      selected_tab: tab,
      feed: requested ++ e(followed, :edges, []),
      page_info: e(followed, :page_info, []),
      previous_page_info: e(socket.assigns, :page_info, false)
    ]
  end

  def load_user_feed_assigns("requested" = tab, _user, params, socket) do
    requested = list_requested(current_user(socket.assigns), input_to_atoms(params))

    [
      loading: false,
      selected_tab: tab,
      back: "/@#{e(current_user(socket.assigns), :character, :username, nil)}",
      feed: requested
      # TODO: pagination
      # page_info: e(requested, :page_info, [])
    ]
  end

  def load_user_feed_assigns("requests" = tab, _user, params, socket) do
    requests = list_requests(current_user(socket.assigns), input_to_atoms(params))

    [
      loading: false,
      back: "/@#{e(current_user(socket.assigns), :character, :username, nil)}",
      selected_tab: tab,
      feed: requests
      # page_info: e(requested, :page_info, [])
    ]
  end

  def load_user_feed_assigns(tab, feed_id, attrs, socket)
      when is_binary(tab) and is_binary(feed_id) do
    params = input_to_atoms(attrs)
    # for custom feeds
    feed_id =
      ulid!(feed_id)
      |> debug("feed_id")

    feed =
      if module_enabled?(FeedActivities, socket),
        do:
          FeedActivities.feed(feed_id,
            pagination: params,
            exclude_feed_ids: e(params, :exclude_feed_ids, []),
            current_user: current_user(socket.assigns)
          )
          |> debug("feed")

    merge_feed_assigns(
      feed,
      [
        loading: false,
        selected_tab: tab,
        feed_id: feed_id
      ],
      e(socket.assigns, :page_info, nil)
    )
  end

  defp list_requested(current_user, pagination) do
    # TODO: apply boundaries to Requests and then be able to view someone's requests/requested that involve me
    # TODO: pagination
    # user,
    Bonfire.Social.Requests.list_my_requested(
      pagination: pagination,
      current_user: current_user,
      type: Bonfire.Data.Social.Follow
    )
    |> debug("requested")
  end

  defp list_requests(current_user, pagination) do
    # TODO: apply boundaries to Requests and then be able to view someone's requests/requested that involve me
    # TODO: pagination
    # user,
    Bonfire.Social.Requests.list_my_requesters(
      pagination: pagination,
      current_user: current_user
    )
    |> debug("requests")
  end

  defp merge_feed_assigns(feed, new_assigns, previous_page_info) do
    {e(feed, :edges, []),
     new_assigns ++
       [
         previous_page_info: previous_page_info || false,
         page_info: e(feed, :page_info, [])
       ]}
  end
end
