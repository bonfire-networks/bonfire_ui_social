defmodule Bonfire.Social.Feeds.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_params(%{"after" => _cursor_after} = attrs, _, %{assigns: %{feed_id: feed_id}} = socket) when not is_nil(feed_id) do
    paginate_feed(feed_id, attrs, socket)
  end

  def handle_params(%{"after" => _cursor_after} = attrs, _, socket) do
    paginate_feed(attrs, socket)
  end

  def handle_params(_attrs, _, socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", attrs, %{assigns: %{feed_id: feed_id}} = socket) when not is_nil(feed_id) do
    paginate_feed(feed_id, attrs, socket)
  end

  def handle_event("load_more", attrs, socket) do
    paginate_feed(attrs, socket)
  end

  def handle_event("reply_to_activity", _, socket) do
    debug("reply!")

    current_user = current_user(socket)

    activity = e(socket.assigns, :activity, nil)

    # Note: we reply to objects, not activities
    reply_to_id =
      e(socket.assigns, :object_id, nil)
      || e(socket.assigns, :object, :id, nil)
      || e(activity, :object, :id, nil)
      || e(activity, :object_id, nil)

    case Bonfire.Boundaries.load_pointer(reply_to_id, current_user: current_user, verbs: [:reply], ids_only: true) do
      %{id: reply_to_id} ->

        # FIXME: don't re-load this here as we already have the list (at least when we're in a thread)
        participants = Bonfire.Social.Threads.list_participants(activity, nil, current_user: current_user)
        to_circles = if length(participants)>0, do: Enum.map(participants, & {e(&1, :character, :username, l "someone"), e(&1, :id, nil)})
        mentions = if length(participants)>0, do: Enum.map_join(participants, " ", & "@"<>e(&1, :character, :username, ""))<>" "
        # IO.inspect(mentions, label: "PARTS")

        thread_id = e(activity, :replied, :thread_id, nil) || e(socket.assigns, :object, :replied, :thread_id, nil)

        debug("send activity to smart input")
        send_update(Bonfire.UI.Common.SmartInputLive, # assigns_merge(socket.assigns,
          id: :smart_input,
          # we reply to objects, not activities
          reply_to_id: reply_to_id,
          thread_id: thread_id,
          smart_input_text: mentions,
          to_circles: to_circles,
          to_boundaries: [Bonfire.Boundaries.preset_boundary_tuple_from_acl(e(socket.assigns, :object_boundary, nil))],
          activity_inception: "reply_to",
          # TODO: use assigns_merge and send_update to the ActivityLive component within smart_input instead, so that `update/2` isn't triggered again
          activity: activity,
          object: e(socket.assigns, :object, nil)
        )

        {:noreply, socket}

      other ->
        debug(other)
        error(l "Sorry, you cannot reply to this")
    end
  end

  def handle_event("remove_data", _params, socket) do
    send_update(Bonfire.UI.Common.SmartInputLive, [
      id: :smart_input,
      activity: nil,
      object: nil,
      reply_to_id: e(socket, :assigns, :thread_id, nil) # default to replying to current thread
    ])
    {:noreply, socket}
  end

  def handle_event("delete", %{"id"=> id} = params, socket) do
    # TODO: check permission
    with num when is_integer(num) <- Bonfire.Social.FeedActivities.delete(id, :id) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign_flash(:info, l("Deleted from %{number} feeds!", number: num))
      }
    end
  end



  def handle_event("open_activity", %{"ignore" => "true"} = _params, socket) do
    {:noreply, socket}
  end

  def handle_event("open_activity", %{"permalink" => permalink} = _params, socket) do
    debug("Redirect to the activity page")
    {:noreply,
      socket
      |> redirect_to(permalink)
    }
  end

  def handle_event("open_activity", _params, socket) do
    {:noreply, socket}
  end

  # def handle_event("mark_seen", _params, %{assigns: %{activity: %{id: activity_id}}} = socket) when is_binary(feed_id) and is_binary(activity_id) do
  #   warn("TODO: mark as read: #{activity_id} in #{feed_id}")

  #   # send_update(Bonfire.UI.Common.BadgeCounterLive, id: feed_id, count--)

  #   {:noreply, socket}
  # end

  def handle_event("mark_seen", %{"scope"=> "all", "feed_id"=> feed_id}, %{assigns: %{count: count}} = socket) when is_binary(feed_id) do
    current_user = current_user(socket)

    marked = if current_user do
      #Task.async(fn -> # asynchronously simply so the count is updated quicker for the user
      debug(feed_id, "mark_seen: all in feed")
      Bonfire.Social.FeedActivities.mark_all_seen(feed_id, current_user: current_user)
      # end)
    end

    {:noreply, socket
    |> assign(
      count: count-(marked || 0) # TODO
    )}
  end

  def handle_event("mark_seen", %{"activity_id"=> activity_id}, %{assigns: %{count: count}} = socket) when is_binary(activity_id) and activity_id !="" do
    current_user = current_user(socket)

    if current_user, do: Task.async(fn ->
      # asynchronously simply so the count is updated quicker for the user
      debug(activity_id, "mark_seen")
      Bonfire.Social.Seen.mark_seen(current_user, activity_id)
    end)

    {:noreply, socket
    |> assign(
      count: count-1
    )}
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
    # info(data)
    current_user = current_user(socket)

    permitted? = Bonfire.Common.Pointers.exists?([id: e(data, :activity, :object, :id, nil)], current_user: current_user) |> debug("checked boundary upon receiving a LivePush")

    if permitted? && is_list(data[:feed_ids]) do
      my_home_feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(current_user)

      feed_ids = if Enum.any?(data[:feed_ids], fn feed_id -> feed_id in my_home_feed_ids end) do
        # if activity targets any feeds we're following and/or meant to see in home feed, then target the home feed component
        data[:feed_ids] ++ [Bonfire.Social.Feeds.my_feed_id(:inbox, current_user)]
      else
        data[:feed_ids]
      end

      debug(feed_ids, "send_update to feeds")

      send_feed_updates(feed_ids, new_activity: data[:activity])
    end
    {:noreply, socket}
  end

  def handle_info({:load_feed, key}, socket) do
    {:noreply, socket
      |> assign(feed_assigns(key, socket))
    }
  end

  def send_feed_updates(feed_ids, assigns, component \\ Bonfire.UI.Social.FeedLive)
  def send_feed_updates(feed_ids, assigns, component) when is_list(feed_ids) do
    for feed_id <- feed_ids do
      send_feed_updates(feed_id, assigns, component)
    end
  end
  def send_feed_updates(feed_id, assigns, component) do
    send_update(component, [id: feed_id] ++ assigns)
  end

  def paginate_feed("user:"<>selected_tab_and_user_id, attrs, socket) do

    {:noreply, socket
      |> assign(load_user_feed_assigns(selected_tab_and_user_id, attrs, socket))
    }
  end

  def paginate_feed(feed_id, attrs, socket) when not is_nil(feed_id) do
    current_user = current_user(socket)
    paginate = input_to_atoms(attrs)

    if(current_user && feed_id == Bonfire.Social.Feeds.my_feed_id(:inbox, current_user)) do
      debug("Feeds - paginate - the feed_id assigned in the view is current user's inbox, so load that")
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

    feed_or_tuple = if current do
      feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket)
      feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(socket)
      {feed_id, feed_ids}
    else
      Bonfire.Social.Feeds.named_feed_id(:local) # fallback to showing instance feed
    end

    feed_assigns = feed_assigns(feed_or_tuple, opts)

    {:noreply, socket
      |> assign(feed_update_mode: "append")
      |> assign(
        feed_assigns
        |> Keyword.put(:feed,
          feed_assigns[:feed]
          |> preloads(socket)
        )
      )}
  end

  defp paginate_fetch_assign_feed(feed_id, opts, socket) do
    feed = Bonfire.Social.FeedActivities.feed(feed_id, opts)

    {:noreply, socket |> assign(
      feed_update_mode: "append",
      feed: e(feed, :edges, [])
        |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ) }
  end


  def feed_assigns_maybe_async(:my = feed_name, socket) do
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket)
    feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(socket)

    assigns = [
      loading: true,
      feed_id: feed_id,
      feed_ids: feed_ids,
      current_user: current_user(socket),
      selected_tab: "feed", # FIXME: clean up page vs tab
      page: "feed",
      page_title: l("My feed"),
      feed_title: l("My feed"),
      # feed_id: feed_name,
      # feed_ids: feed_ids,
      feed: [],
      page_info: nil,

    ]

    feed_assigns_maybe_async_load({feed_id, feed_ids}, assigns, socket)
  end

  def feed_assigns_maybe_async(:fediverse = feed_name, socket) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)

    assigns = [
      loading: true,
      feed_id: feed_id,
      current_user: current_user(socket),
      selected_tab: "fediverse",
      page: "federation", # FIXME: clean up page vs tab
      page_title: l("Federated activities from remote instances"),
      feed_title: l("Activities from around the fediverse"),
      feedback_title: l("Your fediverse feed is empty"),
      feedback_message: l("It seems you and your friends do not follow any other users on a different instance"),
      # feed_id: feed_name,
      feed: [],
      page_info: nil,
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      # sidebar_widgets: [
      #   users: [
      #     main: [
      #       {Bonfire.UI.Common.WidgetInstanceInfoLive, []}
      #     ]
      #   ]
      # ]
    ]

    feed_assigns_maybe_async_load(feed_id, assigns, socket)
  end

  def feed_assigns_maybe_async(:local = feed_name, socket) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    assigns = [
      loading: true,
      feed_id: feed_id,
      current_user: current_user(socket),
      selected_tab: "instance",
      page: "local", # FIXME: clean up page vs tab
      page_title: l("Local activities"),
      feed_title: l("Activities on this instance"),
      # feed_id: feed_name,
      feed: [],
      page_info: nil, #|> IO.inspect
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      # sidebar_widgets: [
      #   users: [
      #     main: [
      #       {Bonfire.UI.Common.WidgetInstanceInfoLive, []}
      #     ]
      #   ]
      # ]
    ]

    feed_assigns_maybe_async_load(feed_id, assigns, socket)
  end

  def feed_assigns_maybe_async(_default, socket) do
    current = current_user(socket) || current_account(socket)

    if current do
      feed_assigns_maybe_async(:my, socket) # my feed
    else
      feed_assigns_maybe_async(:local, socket) # fallback to showing instance feed
    end
  end

  # defp feed_assigns_maybe_async_load(feed_name, assigns, %{assigns: %{loading: false}} = socket) do
  #   debug("Skip loading feed...")
  #   []
  # end
  defp feed_assigns_maybe_async_load(feed_id_or_tuple, assigns, %Phoenix.LiveView.Socket{} = socket) do
    if connected?(socket) and Config.get(:env) != :test do
      # dump(socket.assigns, "connected")
      # send(self(), {Bonfire.Social.Feeds.LiveHandler, {:load_feed, feed_name}})
      pid = self()
      Task.async(fn ->
        # Query activities asynchronously
        send_update(pid, Bonfire.UI.Social.FeedLive, feed_assigns(feed_id_or_tuple, socket) ++ [id: feed_id_only(feed_id_or_tuple)])
      end)

      assigns # return temporary assigns in the meantime

    else
      # dump(socket.assigns, "disconnected")
      # for dead mounts
      assigns ++ feed_assigns(feed_id_or_tuple, socket)
    end
  end
  defp feed_assigns_maybe_async_load(feed_id, assigns, socket) do
    # dump(e(socket, :assigns, nil), "not socket")
    assigns ++ feed_assigns(feed_id, socket)
  end

  defp feed_id_only({feed_id, _feed_ids}), do: feed_id
  defp feed_id_only(feed_id), do: feed_id

  defp feed_assigns({_feed_id, feed_ids}, socket) do
    # debug(myfeed: feed)
    feed = Bonfire.Social.FeedActivities.my_feed(socket, feed_ids)
    [
      loading: false,
      feed: e(feed, :edges, []) |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ]
  end

  defp feed_assigns(feed_id, socket) when is_binary(feed_id) do
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket)
    [
      loading: false,
      feed: e(feed, :edges, []) |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ]
  end

  # defp feed_assigns(feed_id, socket) when is_atom(feed_id) do
  #   feed_id = Bonfire.Social.Feeds.named_feed_id(feed_id)
  #   feed = Bonfire.Social.FeedActivities.feed(feed_id, socket)
  #   [
  #     loading: false,
  #     feed_id: feed_id,
  #     feed: e(feed, :edges, []) |> preloads(socket),
  #     page_info: e(feed, :page_info, [])
  #   ]
  # end

  def preloads(feed, socket \\ [])
  def preloads(feed, socket) when is_list(feed) and length(feed) > 0 do
    debug("FeedLive: preload objects")

    opts = [preload: e(socket, :assigns, :preload, :feed), current_user: current_user(socket), skip_boundary_check: true, with_cache: false]

    case List.first(feed) do

      %{activity: %{id: _}} ->
        feed
        # |> debug("feed of FeedPublish or objects before extra preloads")
        |> Bonfire.Social.Activities.activity_preloads(e(opts, :preload, :feed), opts)
        # |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([activity: [:object]])
        |> preload_objects([:activity, :object], opts)
        # |> debug("feed with extra preloads")

      %{edge: %{id: _}} ->
        feed
        # |> debug("feed of Edge objects before extra preloads")
        |> Bonfire.Social.Activities.activity_preloads(e(opts, :preload, :feed), opts)
        # |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([edge: [:object]])
        |> preload_objects([:edge, :object], opts)
        # |> debug("feed with extra preloads")

      %{object: _} ->
        feed
        # |> debug("feed of activities before extra preloads")
        |> Bonfire.Social.Activities.activity_preloads(e(opts, :preload, :feed), opts)
        # |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([:object])
        |> preload_objects([:object], opts)
        # |> debug("feed with extra preloads")

      _ ->
        warn("Could not preload feed - the data structure was not recognised")
        feed
    end
  end
  def preloads(%{edges: feed} = page, socket), do: Map.put(page, :edges, preloads(feed, socket))
  def preloads(feed, socket), do: feed

  def preload_objects(feed, under, opts) do
    object_preloads()
    |> Bonfire.Common.Repo.Preload.maybe_preloads_per_nested_schema(feed, under, ..., opts)
  end

  def object_preloads do
    [
      # {Bonfire.Data.Social.Post, Bonfire.UI.Social.Activity.NoteLive.preloads()}, # only needed if we no longer preload PostContent by default
      {Bonfire.Data.Identity.User, Bonfire.UI.Social.Activity.CharacterLive.preloads()},
      {Bonfire.Classify.Category, Bonfire.UI.Social.Activity.CategoryLive.preloads()},
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()},
    ]
    |> debug("preload object data in feed")
  end

  def user_feed_assign_or_load_async(tab, user_or_feed, params, %Phoenix.LiveView.Socket{} = socket) do
    if connected?(socket) and Config.get(:env) != :test do
      # dump(socket.assigns, "connected")
      pid = self()
      Task.async(fn ->
        # Query activities asynchronously
        send_update(pid, Bonfire.UI.Social.FeedLive, load_user_feed_assigns(tab, user_or_feed, params, socket) ++ [id: "feed:profile:#{tab}"])
      end)

      # return temporary assigns in the meantime
      {:noreply,
      assign(socket,
        loading: true,
        feed: [],
        selected_tab: tab
      )}

    else
      # dump(socket.assigns, "disconnected")
      # for dead mounts
      {:noreply,
        assign(socket,
          load_user_feed_assigns(tab, user_or_feed, params, socket)
        )}
    end
  end

  def user_feed_assign_or_load_async(tab, user_or_feed, params, socket) do
    # dump(e(socket, :assigns, nil), "not socket")
    {:noreply,
      assign(socket,
        load_user_feed_assigns(tab, user_or_feed, params, socket)
    )}
  end


  def load_user_feed_assigns(selected_tab_and_user_id, params, socket) do # note the 3 arity
    with [selected_tab, user_id] <- String.split(selected_tab_and_user_id, ":") do
      debug(params, "Load and maybe paginate feed for user: #{selected_tab_and_user_id}")
      load_user_feed_assigns(selected_tab, user_id, params, socket)
    end
  end

  def load_user_feed_assigns("posts" = tab, user, params, socket) do # note the 4 arity
    user = user || e(socket, :assigns, :user, nil)
    feed = if module_enabled?(Bonfire.Social.Posts), do: Bonfire.Social.Posts.list_by(user, pagination: input_to_atoms(params), current_user: current_user(socket))
    #|> debug("posts")

    [
       loading: false,
       selected_tab: tab,
       feed: e(feed, :edges, []) |> preloads(socket),
       page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("boosts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    feed = if module_enabled?(Bonfire.Social.Boosts), do: Bonfire.Social.Boosts.list_by(user, pagination: input_to_atoms(params), current_user: current_user(socket))
    # |> debug("boosts")

    [
      loading: false,
      selected_tab: tab,
      feed: e(feed, :edges, []) |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns(tab, feed_id, attrs, socket) when is_binary(tab) and is_binary(feed_id) do
    params = input_to_atoms(attrs)
    # for custom feeds
    feed_id = ulid!(feed_id)
    feed = if module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, pagination: params, exclude_feed_ids: e(params, :exclude_feed_ids, []), current_user: current_user(socket))
    #  debug(feed: feed)

    [
      loading: false,
      selected_tab: tab,
      feed_id: feed_id,
      feed: e(feed, :edges, []) |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("timeline" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    feed_id = if user && module_enabled?(Bonfire.Social.Feeds), do: Bonfire.Social.Feeds.feed_id(:outbox, user)
    feed = if feed_id && module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, pagination: input_to_atoms(params), current_user: current_user(socket))
    #  debug(feed: feed)

    [
      loading: false,
      selected_tab: tab,
      feed_id: feed_id,
      feed: e(feed, :edges, []) |> preloads(socket),
      page_info: e(feed, :page_info, [])
    ]
  end

  def load_user_feed_assigns("followers" =tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    followers = Bonfire.Social.Follows.list_followers(user, pagination: input_to_atoms(params), current_user: current_user(socket)) #|> debug("followers")

    [
      loading: false,
      selected_tab: tab,
      feed: e(followers, :edges, []),
      page_info: e(followers, :page_info, [])
    ]
  end

  def load_user_feed_assigns("followed" =tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    followed = Bonfire.Social.Follows.list_followed(user, pagination: input_to_atoms(params), current_user: current_user(socket)) #|> dump("followed")

    [
      loading: false,
      selected_tab: tab,
      feed: e(followed, :edges, []),
      page_info: e(followed, :page_info, [])
    ]
  end


end
