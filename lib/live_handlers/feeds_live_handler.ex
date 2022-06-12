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

    activity = e(socket.assigns, :activity, nil)

    # FIXME: don't re-load this here as we already have the list (at least when we're in a thread)
    participants = Bonfire.Social.Threads.list_participants(activity, nil, current_user: current_user(socket))
    to_circles = if length(participants)>0, do: Enum.map(participants, & {e(&1, :character, :username, l "someone"), e(&1, :id, nil)})
    mentions = if length(participants)>0, do: Enum.map_join(participants, " ", & "@"<>e(&1, :character, :username, ""))<>" "
    # IO.inspect(mentions, label: "PARTS")

    # we reply to objects, not activities
    reply_to_id =
      e(socket.assigns, :object_id, nil)
      || e(socket.assigns, :object, :id, nil)
      || e(activity, :object, :id, nil)
      || e(activity, :object_id, nil)

    thread_id = e(activity, :replied, :thread_id, nil) || e(socket.assigns, :object, :replied, :thread_id, nil)

    debug("send activity to smart input")
    send_update(Bonfire.UI.Common.SmartInputLive, # assigns_merge(socket.assigns,
      id: :smart_input,
      # we reply to objects, not activities
      reply_to_id: reply_to_id,
      thread_id: thread_id,
      smart_input_text: mentions,
      to_circles: to_circles,
      activity_inception: "reply_to",
      preset_boundary: Bonfire.Boundaries.preset_boundary_name_from_acl(e(socket.assigns, :object_boundary, nil)),
      # TODO: use assigns_merge and send_update to the ActivityLive component within smart_input instead, so that `update/2` isn't triggered again
      activity: activity,
      object: e(socket.assigns, :object, nil)
    )

    {:noreply, socket}
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
    with num when is_integer(num) <- Bonfire.Social.FeedActivities.delete(id) do
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
    warn(feed_ids, "count_increment")

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
    assign_user_feed(selected_tab_and_user_id, attrs, socket)
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
    feed_assigns = feed_assigns(:default, opts)

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


  def load_feed_assigns(:my = feed_name, socket_or_opts) do
    assigns = [
      loading: true,
      # current_user: current_user,
      selected_tab: "home", # FIXME: clean up page vs tab
      page: "home",
      page_title: l("Home"),
      feed_title: l("My feed"),
      feed_id: feed_name,
      # feed_ids: feed_ids,
      feed: [],
      page_info: nil,
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Common.WidgetInstanceInfoLive, []}
          ],
          secondary: [
            {Bonfire.UI.Social.WidgetTimelinesLive, [page: "home"]},
            {Bonfire.UI.Social.WidgetTagsLive , []}
          ]
        ]
      ]
    ]

    feed_assigns_or_load_async(feed_name, assigns, socket_or_opts)
  end

  def load_feed_assigns(:fediverse = feed_name, socket_or_opts) do
    assigns = [
      loading: true,
      # current_user: current_user(socket_or_opts),
      selected_tab: "fediverse",
      page: "federation", # FIXME: clean up page vs tab
      page_title: l("Federated activities from remote instances"),
      feed_title: l("Activities from around the fediverse"),
      feedback_title: l("Your fediverse feed is empty"),
      feedback_message: l("It seems you and your friends do not follow any other users on a different instance"),
      feed_id: feed_name,
      feed: [],
      page_info: nil,
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Common.WidgetInstanceInfoLive, []}
          ],
          secondary: [
            {Bonfire.UI.Social.WidgetTimelinesLive, [page: "federation"]},
            {Bonfire.UI.Social.WidgetTagsLive , []}
          ]
        ]
      ]
    ]

    feed_assigns_or_load_async(feed_name, assigns, socket_or_opts)
  end

  def load_feed_assigns(:local = feed_name, socket_or_opts) do
    assigns = [
      loading: true,
      # current_user: current_user(socket_or_opts),
      selected_tab: "instance",
      page: "local", # FIXME: clean up page vs tab
      page_title: l("Local activities"),
      feed_title: l("Activities on this instance"),
      feed_id: feed_name,
      feed: [],
      page_info: nil, #|> IO.inspect
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Common.WidgetInstanceInfoLive, []}
          ],
          secondary: [
            {Bonfire.UI.Social.WidgetTimelinesLive, [page: "local"]},
            {Bonfire.UI.Social.WidgetTagsLive , []}
          ]
        ]
      ]
    ]

    feed_assigns_or_load_async(feed_name, assigns, socket_or_opts)
  end

  def load_feed_assigns(_default, socket_or_opts) do
    current = current_user(socket_or_opts) || current_account(socket_or_opts)

    if current do
      load_feed_assigns(:my, socket_or_opts) # my feed
    else
      load_feed_assigns(:local, socket_or_opts) # fallback to showing instance feed
    end
  end

  defp feed_assigns_or_load_async(feed_name, assigns, %Phoenix.LiveView.Socket{} = socket) do
    if connected?(socket) and Config.get(:env) != :test do
      send(self(), {Bonfire.Social.Feeds.LiveHandler, {:load_feed, feed_name}})
      assigns
    else
      assigns ++ feed_assigns(feed_name, socket)
    end
  end
  defp feed_assigns_or_load_async(feed_name, assigns, socket_or_opts) do
    assigns ++ feed_assigns(feed_name, socket_or_opts)
  end

  def feed_assigns(:my, socket_or_opts) do
    # debug(myfeed: feed)
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket_or_opts)
    feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(socket_or_opts)
    feed = Bonfire.Social.FeedActivities.my_feed(socket_or_opts, feed_ids)
    [
      loading: false,
      current_user: current_user(socket_or_opts),
      feed_id: feed_id,
      feed_ids: feed_ids,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def feed_assigns(:fediverse, socket_or_opts) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket_or_opts)

    [
      loading: false,
      current_user: current_user(socket_or_opts),
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def feed_assigns(:local, socket_or_opts) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket_or_opts)

    [
      loading: false,
      current_user: current_user(socket_or_opts),
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def feed_assigns(_default, socket_or_opts) do
    current = current_user(socket_or_opts) || current_account(socket_or_opts)

    if current do
      feed_assigns(:my, socket_or_opts) # my feed
    else
      feed_assigns(:local, socket_or_opts) # fallback to showing instance feed
    end
  end

  def preloads(feed, socket_or_opts \\ [])
  def preloads(feed, socket_or_opts) when is_list(feed) and length(feed) > 0 do
    debug("FeedLive: preload objects")

    opts = [preload: e(socket_or_opts, :assigns, :preload, :feed), current_user: current_user(socket_or_opts), skip_boundary_check: true, with_cache: false]

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
  def preloads(%{edges: feed} = page, socket_or_opts), do: Map.put(page, :feed, preloads(feed, socket_or_opts))
  def preloads(feed, socket_or_opts), do: feed

  def preload_objects(feed, under, opts) do
    object_preloads()
    |> Bonfire.Common.Repo.Preload.maybe_preloads_per_nested_schema(feed, under, ..., opts)
  end

  def object_preloads do
    [
      # {Bonfire.Data.Social.Post, Bonfire.UI.Social.Activity.NoteLive.preloads()}, # only needed if we no longer preload PostContent by default
      {Bonfire.Data.Identity.User, Bonfire.UI.Social.Activity.CharacterLive.preloads()},
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()},
    ]
    |> debug("preload object data in feed")
  end

  def assign_user_feed(selected_tab_and_user_id, params, socket) do
    with [selected_tab, user_id] <- String.split(selected_tab_and_user_id, ":") do
      debug(params, "Load and maybe paginate feed for user: #{selected_tab_and_user_id}")
      assign_user_feed(selected_tab, user_id, params, socket)
    end
  end

  def assign_user_feed("posts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    feed = if module_enabled?(Bonfire.Social.Posts), do: Bonfire.Social.Posts.list_by(user, pagination: input_to_atoms(params), current_user: current_user(socket))
    #|> debug("posts")

    {:noreply,
     assign(socket,
       selected_tab: tab,
       feed: e(feed, :edges, []),
       page_info: e(feed, :page_info, [])
     )}
  end

  def assign_user_feed("boosts" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    feed = if module_enabled?(Bonfire.Social.Boosts), do: Bonfire.Social.Boosts.list_by(user, pagination: input_to_atoms(params), current_user: current_user(socket))
    # |> debug("boosts")

    {:noreply,
      assign(socket,
        selected_tab: tab,
        feed: e(feed, :edges, []),
        page_info: e(feed, :page_info, [])
      )}
  end

  def assign_user_feed("timeline" = tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    feed_id = if user && module_enabled?(Bonfire.Social.Feeds), do: Bonfire.Social.Feeds.feed_id(:outbox, user)
    feed = if feed_id && module_enabled?(Bonfire.Social.FeedActivities), do: Bonfire.Social.FeedActivities.feed(feed_id, pagination: input_to_atoms(params), current_user: current_user(socket))
    #  debug(feed: feed)

    {:noreply,
      assign(socket,
      selected_tab: tab,
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
      )}
  end

  def assign_user_feed("followers" =tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    followers = Bonfire.Social.Follows.list_followers(user, pagination: input_to_atoms(params), current_user: current_user(socket)) |> debug("followers")

    {:noreply,
    assign(socket,
      selected_tab: tab,
      feed: e(followers, :edges, []),
      page_info: e(followers, :page_info, [])
    )}
  end

  def assign_user_feed("followed" =tab, user, params, socket) do
    user = user || e(socket, :assigns, :user, nil)
    followed = Bonfire.Social.Follows.list_followed(user, pagination: input_to_atoms(params), current_user: current_user(socket)) |> debug("followed")

    {:noreply,
    assign(socket,
      selected_tab: tab,
      feed: e(followed, :edges, []),
      page_info: e(followed, :page_info, [])
    )}
  end

end
