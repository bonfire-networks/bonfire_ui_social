defmodule Bonfire.Social.Feeds.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  use Untangle
  alias Bonfire.Social.Activities
  alias Bonfire.Data.Social.Activity

  def handle_params(
        %{"after" => _cursor_after} = attrs,
        _,
        %{assigns: %{feed_id: feed_id}} = socket
      )
      when not is_nil(feed_id) do
    paginate_feed(feed_id, attrs, socket)
  end

  def handle_params(%{"after" => _cursor_after} = attrs, _, socket) do
    paginate_feed(attrs, socket)
  end

  def handle_params(_attrs, _, socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", attrs, %{assigns: %{feed_id: feed_id}} = socket)
      when not is_nil(feed_id) do
    paginate_feed(feed_id, attrs, socket)
  end

  def handle_event("load_more", attrs, socket) do
    paginate_feed(attrs, socket)
  end

  def handle_event("reply_to_activity", _params, socket) do
    debug("reply!")

    activity = e(socket.assigns, :activity, %{})

    # Note: we reply to objects, not activities
    reply_to =
      e(socket.assigns, :object, nil) ||
        e(activity, :object, nil) ||
        e(socket.assigns, :object_id, nil) ||
        e(activity, :object_id, nil)

    reply_to_id = Enums.id(reply_to)

    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("reply"), reply_to),
         # TODO: can we use the preloaded object_boundaries rather than making an extra query
         true <- Bonfire.Boundaries.can?(current_user, :reply, reply_to_id) do
      # TODO: don't re-load participants here as we already have the list (at least when we're in a thread)
      # TODO: include thread_id in list_participants/3 call
      participants =
        (Bonfire.Social.Threads.list_participants(Map.put(activity, :object, reply_to), nil,
           current_user: current_user
         ) || [])
        |> Enum.reject(&(e(&1, :character, :id, nil) == id(current_user)))

      to_circles =
        if participants != [],
          do:
            Enum.map(participants, &{e(&1, :character, :username, l("someone")), e(&1, :id, nil)})

      mentions =
        if participants != [],
          do: Enum.map_join(participants, " ", &("@" <> e(&1, :character, :username, ""))) <> " "

      thread_id =
        e(activity, :replied, :thread_id, nil) ||
          e(socket.assigns, :object, :replied, :thread_id, nil)

      debug(mentions, "send activity to smart input")

      Bonfire.UI.Common.SmartInput.LiveHandler.open_with_text_suggestion(
        mentions,
        # we reply to objects, not
        [
          # reset_smart_input: false, # avoid double-reset
          reply_to_id: reply_to_id,
          context_id: thread_id,
          to_circles: to_circles || [],
          create_object_type:
            if(e(socket.assigns, :object_type, nil) == Bonfire.Data.Social.Message, do: :message),
          to_boundaries: [
            Bonfire.Boundaries.preset_boundary_tuple_from_acl(
              e(socket.assigns, :object_boundary, nil)
            )
          ],
          activity_inception: "reply_to",
          # TODO: use assigns_merge and send_update to the ActivityLive component within smart_input instead, so that `update/2` isn't triggered again
          activity: activity,
          object: reply_to
        ],
        socket.assigns[:__context__]
      )

      {:noreply, socket}
    else
      false ->
        error(l("Sorry, you cannot reply to this"))

      other ->
        # for remote interaction redirect
        other
    end
  end

  def handle_event("delete", %{"id" => id} = _params, socket) do
    # TODO: check permission
    with num when is_integer(num) <- Bonfire.Social.FeedActivities.delete(id, :id) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, l("Deleted from %{number} feeds!", number: num))}
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
        # Task.async(fn -> # asynchronously simply so the count is updated quicker for the user
        debug(feed_id, "mark_seen: all in feed")
        Bonfire.Social.FeedActivities.mark_all_seen(feed_id, current_user: current_user)
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
        async_task(fn ->
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

    send_feed_updates(feed_ids, [count_increment: 1], Bonfire.UI.Common.BadgeCounterLive)

    {:noreply, socket}
  end

  def handle_info({:new_activity, data}, socket) do
    debug(data[:feed_ids], "received new_activity for these feed ids")
    # dump(data)
    current_user = current_user(socket)

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

  def handle_info({:load_feed, key}, socket) do
    {:noreply,
     socket
     |> assign_generic(feed_assigns(key, socket))}
  end

  def reply_to_activity(js \\ %JS{}, activity_component_id) do
    js
    |> JS.push(
      "Bonfire.Social.Feeds:reply_to_activity",
      target: "##{activity_component_id}"
    )
    |> Bonfire.UI.Common.SmartInput.LiveHandler.maximize()
  end

  defp send_feed_updates(feed_ids, assigns, component \\ Bonfire.UI.Social.FeedLive)

  defp send_feed_updates(feed_ids, assigns, component) when is_list(feed_ids) do
    for feed_id <- feed_ids do
      send_feed_updates(feed_id, assigns, component)
    end
  end

  defp send_feed_updates(feed_id, assigns, component) do
    debug(feed_id, "Sending feed update to")
    maybe_send_update(component, feed_id, assigns)
  end

  def paginate_feed("user-" <> selected_tab_and_user_id, attrs, socket) do
    {:noreply,
     socket
     |> assign_generic(load_user_feed_assigns(selected_tab_and_user_id, attrs, socket))}
  end

  def paginate_feed(feed_id, attrs, socket) when not is_nil(feed_id) do
    current_user = current_user(socket)
    paginate = input_to_atoms(attrs)

    if(current_user && feed_id == Bonfire.Social.Feeds.my_feed_id(:inbox, current_user)) do
      debug(
        "Feeds - paginate - the feed_id assigned in the view is current user's inbox, so load that"
      )

      paginate_fetch_assign_default([current_user: current_user, paginate: paginate], socket)
    else
      feed_id
      |> debug("Feeds - paginate - a feed_id has been assigned in the view, so load that")
      |> paginate_fetch_assign_feed([current_user: current_user, paginate: paginate], socket)
    end
  end

  def paginate_feed(attrs, socket) do
    input_to_atoms(attrs)
    |> debug("Feeds - paginate - there's no feed_id, so load the default")
    |> paginate_fetch_assign_default([current_user: current_user(socket), paginate: ...], socket)
  end

  def paginate_fetch_assign_default(opts, socket) do
    current = current_user(socket) || current_account(socket)

    feed_or_tuple =
      if current do
        feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket)
        feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(socket)
        {feed_id, feed_ids}
      else
        # fallback to showing instance feed
        Bonfire.Social.Feeds.named_feed_id(:local)
      end

    feed_assigns = feed_assigns(feed_or_tuple, opts)

    {:noreply,
     socket
     |> assign_generic(feed_update_mode: "append")
     |> assign_generic(
       feed_assigns
       |> Keyword.put(
         :feed,
         feed_assigns[:feed]
       )
     )}
  end

  defp paginate_fetch_assign_feed(feed_id, opts, socket) do
    feed = Bonfire.Social.FeedActivities.feed(feed_id, opts)

    {:noreply,
     socket
     |> assign_generic(
       feed_update_mode: "append",
       feed: e(feed, :edges, []),
       page_info: e(feed, :page_info, [])
     )}
  end

  defp feed_filter_assigns(%{"object_type" => "discussions" = filter}),
    do: [
      tab_path_suffix: "/#{filter}",
      page_title: l("Discussions"),
      page_header_icon: "ri:chat-1-line"
    ]

  defp feed_filter_assigns(%{"object_type" => "posts" = filter}),
    do: [
      tab_path_suffix: "/#{filter}",
      page_title: l("Posts"),
      page_header_icon: "ri:file-text-line"
    ]

  defp feed_filter_assigns(_),
    do: [tab_path_suffix: nil, page_title: l("Activities"), page_header_icon: "ri:home-line"]

  @decorate time()
  def feed_assigns_maybe_async({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket) do
    feed_name = feed_name(feed_name, socket)
    debug(filters_or_custom_query_or_feed_id_or_ids, feed_name)

    assigns =
      (feed_default_assigns(feed_name, socket) ++
         feed_filter_assigns(filters_or_custom_query_or_feed_id_or_ids))
      |> debug("start by setting feed_default_assigns")

    feed_assigns_maybe_async_load(
      {feed_name, filters_or_custom_query_or_feed_id_or_ids},
      assigns,
      socket
    )
  end

  def feed_assigns_maybe_async(other, socket) do
    feed_name = feed_name(other, socket)
    # debug(other, feed_name)

    assigns =
      feed_default_assigns(feed_name, socket)
      |> debug("start by setting feed_default_assigns")

    feed_assigns_maybe_async_load(
      {feed_name, assigns[:feed_ids] || assigns[:feed_id]},
      assigns,
      socket
    )
  end

  defp feed_default_assigns(:my = feed_name, socket) do
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket)

    feed_ids =
      Bonfire.Social.Feeds.my_home_feed_ids(socket)
      |> debug(feed_name)

    [
      loading: true,
      feed_id: feed_id,
      feed_ids: feed_ids,
      feed_component_id: component_id(feed_id, socket.assigns),
      # FIXME: clean up page vs tab
      selected_tab: nil,
      page: "feed",
      # page_title: l("My feed"),
      # feed_title: l("My feed"),
      # feed_id: feed_name,
      # feed_ids: feed_ids,
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_default_assigns(:fediverse = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:activity_pub)
      |> debug(feed_name)

    [
      loading: true,
      feed_id: feed_id,
      feed_component_id: component_id(feed_id, socket.assigns),
      selected_tab: :fediverse,
      # FIXME: clean up page vs tab
      page: "federation",
      page_header_icon: "ri:home-line",
      # page_title: l("Federated activities from remote instances"),
      # feed_title: l("Activities from around the fediverse"),
      feedback_title: l("Your fediverse feed is empty"),
      feedback_message:
        l(
          "It seems you and other local users do not follow anyone on a different federated instance"
        ),
      # feed_id: feed_name,
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_default_assigns(:local = feed_name, socket) do
    feed_id =
      Bonfire.Social.Feeds.named_feed_id(:local)
      |> debug(feed_name)

    [
      loading: true,
      feed_id: feed_id,
      feed_component_id: component_id(feed_id, socket.assigns),
      selected_tab: :local,
      # FIXME: clean up page vs tab
      page: "local",
      # page_title: l("Activities from members of the local instance"),
      feedback_title: l("Your local feed is empty"),
      # feed_id: feed_name,
      feedback_message: l("It seems like the paint is still fresh on this instance..."),
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_default_assigns(:likes = feed_name, socket) do
    # debug(feed_name)

    [
      loading: true,
      feed_id: feed_name,
      feed_component_id: component_id(feed_name, socket.assigns),
      selected_tab: :likes,
      # FIXME: clean up page vs tab
      page: "local",
      # page_title: l("My favourites"),
      # feed_title: l("My favourites"),
      feedback_title: l("You have no favourites yet"),
      # feed_id: feed_name,
      # feedback_message: l("It seems like the paint is still fresh on this instance..."),
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_default_assigns({feed_name, filters_or_custom_query_or_feed_id_or_ids}, socket)
       when is_atom(feed_name) do
    debug(filters_or_custom_query_or_feed_id_or_ids, feed_name)

    feed_default_assigns(feed_name, socket)
  end

  defp feed_default_assigns(feed_name, socket) when is_atom(feed_name) do
    debug(feed_name)

    [
      loading: true,
      feed_id: feed_name,
      feed_component_id: component_id(feed_name, socket.assigns),
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_default_assigns(other, socket) do
    debug(other)

    [
      loading: true,
      feed_component_id: component_id(other, socket.assigns),
      feed: :loading,
      page_info: nil
    ]
  end

  defp feed_name(name, socket) when is_nil(name) or name == :default do
    # || current_account(socket)
    current = current_user(socket)

    if not is_nil(ulid(current)) do
      # my feed
      :my
    else
      # fallback to showing instance feed
      :local
    end
    |> debug("default feed to load:")
  end

  defp feed_name(name, _socket) do
    name
  end

  defp component_id(feed_id_or_tuple, assigns),
    do:
      (e(assigns, :feed_component_id, nil) || feed_id_only(feed_id_or_tuple) || :feeds)
      |> debug()

  # defp feed_assigns_maybe_async_load(feed_name, assigns, %{assigns: %{loading: false}} = socket) do
  #   debug("Skip loading feed...")
  #   []
  # end
  defp feed_assigns_maybe_async_load(
         feed_id_or_tuple,
         assigns,
         %Phoenix.LiveView.Socket{} = socket
       ) do
    socket_connected = connected?(socket)

    if (socket_connected || current_user(socket)) && Config.env() != :test do
      if socket_connected do
        debug("socket connected, so load feed async")
        pid = self()

        async_task(fn ->
          debug(feed_id_or_tuple, "Query activities asynchronously")

          feed_assigns(feed_id_or_tuple, socket)
          # Bonfire.Common.Benchmark.apply_timed(&feed_assigns/2, [feed_id_or_tuple, socket])
          # |> debug("feed_assigns")
          |> maybe_send_update(
            pid,
            Bonfire.UI.Social.FeedLive,
            assigns[:feed_component_id] || :feeds,
            ...
          )
        end)
      else
        debug("socket NOT connected, but logged in, so no need to load for SEO")
      end

      # return temporary assigns in the meantime
      assigns
    else
      debug("socket not connected or not logged in, load feed synchronously")

      case feed_assigns(feed_id_or_tuple, socket) do
        fa when is_list(fa) -> assigns ++ fa
        e -> e
      end
    end
  end

  defp feed_assigns_maybe_async_load(feed_id, assigns, socket) do
    # debug(e(socket, :assigns, nil), "not socket")
    assigns ++ feed_assigns(feed_id, socket)
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
       when feed_id == :my or is_list(feed_id_or_ids) do
    # My Feed
    with %{edges: feed, page_info: page_info} <-
           feed_id_or_ids
           |> debug("feed_id_or_ids")
           |> Bonfire.Social.FeedActivities.my_feed(socket, ...) do
      [
        loading: false,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns({feed_id, %{} = filters}, socket) when filters != %{} do
    with %{edges: feed, page_info: page_info} <-
           {feed_id, filters}
           |> debug("filters")
           |> Bonfire.Social.FeedActivities.feed(socket) do
      [
        loading: false,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns(feed_id, socket) when is_binary(feed_id) do
    with %{edges: feed, page_info: page_info} <-
           feed_id
           |> debug("feed_id")
           |> Bonfire.Social.FeedActivities.feed(..., socket) do
      [
        loading: false,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns(:likes = _feed_id, socket) do
    with %{edges: feed, page_info: page_info} <-
           Bonfire.Social.Likes.list_my(current_user: current_user_required!(socket)) do
      feed
      |> debug("likes")

      [
        loading: false,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns(%Ecto.Query{} = custom_query, socket) do
    with %{edges: feed, page_info: page_info} <-
           custom_query
           |> debug("custom_query")
           |> Bonfire.Social.FeedActivities.feed(socket) do
      [
        loading: false,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns(feed_id, socket) when is_atom(feed_id) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(feed_id, socket)

    with %{edges: feed, page_info: page_info} <-
           Bonfire.Social.FeedActivities.feed(feed_id, socket) do
      [
        loading: false,
        feed_id: feed_id,
        feed: feed,
        page_info: page_info
      ]
    end
  end

  defp feed_assigns({feed_id, other}, socket) when is_atom(feed_id) and not is_nil(feed_id) do
    warn(other, "ignoring param")
    feed_assigns(feed_id, socket)
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
      object_type: e(assigns, :object_type, nil)
    }
  end

  @decorate time()
  defp preload_extras(list_of_components, _list_of_ids, current_user) do
    # TODO: less preloads if not in a feed
    preloads = [:feed, :with_reply_to, :with_media]

    opts = [
      preload: preloads,
      with_cache: false,
      current_user: current_user,
      # skip boundary because it should already be checked it the initial query
      skip_boundary_check: true
    ]

    list_of_activities =
      list_of_components
      |> Enum.map(fn
        %{activity: %{__struct__: _} = activity} ->
          debug(activity, "struct")
          activity

        %{activity: %{} = activity} ->
          struct(Activity, activity)

        %{object: %{__struct__: _} = object} ->
          %Activity{object: object}

        other ->
          warn(other, "cannot preload")
          nil
      end)
      |> filter_empty([])
      |> preload_activity_and_object_assocs([:object], opts)
      |> Map.new(fn activity -> {id(activity) || id(e(activity, :object, nil)), activity} end)

    # |> debug()

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

    if (socket_connected || current_user(socket)) && Config.env() != :test do
      if socket_connected do
        debug(tab, "socket connected, so load async")
        pid = self()

        async_task(fn ->
          debug("Query user activities asynchronously")

          load_user_feed_assigns(tab, user_or_feed, params, socket)
          |> maybe_send_update(
            pid,
            Bonfire.UI.Social.FeedLive,
            "feed:profile:#{tab}",
            ...
          )
        end)
      else
        debug(tab, "socket NOT connected, but logged in, so no need to load for SEO")
      end

      # return temporary assigns in the meantime
      {:noreply,
       assign(socket,
         loading: true,
         feed: :loading,
         selected_tab: tab
       )}
    else
      debug(tab, "socket not connected or not logged in, just load feed")
      # for dead mounts
      {:noreply,
       assign(
         socket,
         load_user_feed_assigns(tab, user_or_feed, params, socket)
       )}
    end
  end

  def user_feed_assign_or_load_async(tab, user_or_feed, params, socket) do
    debug(tab, "not a socket, just load feed")

    {:noreply,
     assign(
       socket,
       load_user_feed_assigns(tab, user_or_feed, params, socket)
     )}
  end

  # note the 3 arity
  def load_user_feed_assigns(selected_tab_and_user_id, params, socket) do
    with [selected_tab, user_id] <- String.split(selected_tab_and_user_id, ":") do
      debug(params, "Load and maybe paginate feed for user: #{selected_tab_and_user_id}")
      load_user_feed_assigns(selected_tab, user_id, params, socket)
    end
  end

  # note the 4 arity
  def load_user_feed_assigns("posts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed =
      if module_enabled?(Bonfire.Social.Posts, user),
        do:
          Bonfire.Social.Posts.list_by(user,
            pagination: input_to_atoms(params),
            current_user: current_user(socket)
          )

    # |> debug("posts")

    [
      loading: false,
      selected_tab: tab,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("boosts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed =
      if module_enabled?(Bonfire.Social.Boosts, user),
        do:
          Bonfire.Social.Boosts.list_by(user,
            pagination: input_to_atoms(params),
            current_user: current_user(socket)
          )

    # |> debug("boosts")

    [
      loading: false,
      selected_tab: tab,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns(tab, feed_id, attrs, socket)
      when is_binary(tab) and is_binary(feed_id) do
    params = input_to_atoms(attrs)
    # for custom feeds
    feed_id = ulid!(feed_id)

    feed =
      if module_enabled?(Bonfire.Social.FeedActivities, socket),
        do:
          Bonfire.Social.FeedActivities.feed(feed_id,
            pagination: params,
            exclude_feed_ids: e(params, :exclude_feed_ids, []),
            current_user: current_user(socket)
          )

    #  debug(feed: feed)

    [
      loading: false,
      selected_tab: tab,
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("timeline" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)

    feed_id =
      if user && module_enabled?(Bonfire.Social.Feeds, user),
        do: Bonfire.Social.Feeds.feed_id(:outbox, user)

    feed =
      if feed_id && module_enabled?(Bonfire.Social.FeedActivities, user),
        do:
          Bonfire.Social.FeedActivities.feed(feed_id,
            pagination: input_to_atoms(params),
            current_user: current_user(socket)
          )

    #  debug(feed: feed)

    [
      loading: false,
      selected_tab: tab,
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns(tab, user, params, socket) when tab in ["followers", "members"] do
    user = user || e(socket, :assigns, :user, nil)
    current_user = current_user(socket)
    pagination = input_to_atoms(params)

    requests =
      if id(user) == id(current_user), do: list_requests(current_user, pagination), else: []

    followers =
      Bonfire.Social.Follows.list_followers(user,
        pagination: pagination,
        current_user: current_user
      )
      |> debug("followers")

    [
      loading: false,
      selected_tab: tab,
      feed: requests ++ e(followers, :edges, []),
      page_info: e(followers, :page_info, [])
    ]
  end

  def load_user_feed_assigns("followed" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    current_user = current_user(socket)
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
      selected_tab: tab,
      feed: requested ++ e(followed, :edges, []),
      page_info: e(followed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("requested" = tab, _user, params, socket) do
    requested = list_requested(current_user(socket), input_to_atoms(params))

    [
      loading: false,
      selected_tab: tab,
      feed: requested
      # feed: e(requested, :edges, []),
      # page_info: e(requested, :page_info, [])
    ]
  end

  def load_user_feed_assigns("requests" = tab, _user, params, socket) do
    requested = list_requests(current_user(socket), input_to_atoms(params))

    [
      loading: false,
      selected_tab: tab,
      feed: requested
      # feed: e(requested, :edges, []),
      # page_info: e(requested, :page_info, [])
    ]
  end

  defp list_requested(current_user, pagination) do
    # TODO: apply boundaries to Requests and then be able to view someone's requests/requested that involve me
    # TODO: pagination
    # user,
    Bonfire.Social.Requests.list_my_requested(
      pagination: pagination,
      current_user: current_user
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
end
