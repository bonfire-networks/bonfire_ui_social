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
    # debug("reply!")

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
    send_update(Bonfire.UI.Common.SmartInputLive,
      id: :smart_input,
      # we reply to objects, not activities
      reply_to_id: reply_to_id,
      thread_id: thread_id,
      activity: activity,
      object: e(socket.assigns, :object, nil),
      smart_input_text: mentions,
      to_circles: to_circles,
      activity_inception: "reply_to",
      preset_boundary: Bonfire.Boundaries.preset_boundary_name_from_acl(e(socket.assigns, :object_boundary, nil))
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

  # def handle_event("mark_read", _params, %{assigns: %{feed_id: feed_id, activity: %{id: activity_id}}} = socket) when is_binary(feed_id) and is_binary(activity_id) do
  #   warn("TODO: mark as read: #{activity_id} in #{feed_id}")

  #   # send_update(Bonfire.UI.Common.BadgeCounterLive, id: feed_id, count--)

  #   {:noreply, socket}
  # end

  def handle_event("mark_read", %{"feed_id"=> feed_id, "activity_id"=> activity_id}, %{assigns: %{count: count}} = socket) when is_binary(feed_id) and is_binary(activity_id) do
    current_user = current_user(socket)

    if current_user, do: Task.async(fn ->
      # asynchronously simply so the count is updated quicker for the user
      debug("mark as read: #{activity_id} in #{feed_id}")
      Bonfire.Social.Seens.mark_seen(current_user, activity_id)
    end)

    {:noreply, socket
    |> assign(
      count: count-1
    )}
  end

  def handle_event("mark_read", params, socket) do
    # warn(assigns, "mark as read: needed params not found")
    warn(params, "mark as read: needed params not found")
    {:noreply, socket}
  end

  def handle_info({:count_increment, feed_ids}, socket) do
    warn(feed_ids, "count_increment")

    send_updates(feed_ids, [count_increment: 1], Bonfire.UI.Common.BadgeCounterLive)

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

      send_updates(feed_ids, new_activity: data[:activity])
    end
    {:noreply, socket}
  end

  def send_updates(feed_ids, assigns, component \\ Bonfire.UI.Social.FeedLive) do
    for feed_id <- feed_ids do
      # debug(feed_id, "send_update")
      send_update(component, [id: feed_id] ++ assigns)
    end
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
    {:noreply, socket
      |> assign(feed_update_mode: "append")
      |> assign(
        default_feed_assigns(opts)
      )}
  end

  defp paginate_fetch_assign_feed(feed_id, opts, socket) do
    feed = Bonfire.Social.FeedActivities.feed(feed_id, opts)

    {:noreply, socket |> assign(
      feed_update_mode: "append",
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ) }
  end


  def default_feed_assigns(socket_or_opts) do
    current_user = current_user(socket_or_opts)
    current_account = current_account(socket_or_opts)

    current = current_user || current_account

    if current do
      my_feed_assigns(current, socket_or_opts) # my feed
    else
      instance_feed_assigns(socket_or_opts) # fallback to showing instance feed
    end
  end

  def my_feed_assigns(current_user, socket_or_opts) do
    # debug(myfeed: feed)
    feed_id = Bonfire.Social.Feeds.my_feed_id(:inbox, socket_or_opts)
    feed_ids = Bonfire.Social.Feeds.my_home_feed_ids(socket_or_opts)
    feed = Bonfire.Social.FeedActivities.my_feed(socket_or_opts, feed_ids)
    [
      current_user: current_user,
      selected_tab: "home",
      page_title: l("Home"),
      feed_title: l("My feed"),
      feed_id: feed_id,
      feed_ids: feed_ids,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, [])
    ]
  end

  def fediverse_feed_assigns(socket_or_opts) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:activity_pub)
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket_or_opts)

    [
      current_user: current_user(socket_or_opts),
      selected_tab: "fediverse",
      page_title: l("Federated activities from remote instances"),
      page: "federation",
      feed_title: l("Activities from around the fediverse"),
      feedback_title: l("Your fediverse feed is empty"),
      feedback_message: l("It seems you and your friends do not follow any other users on a different instance"),
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, []),
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Common.HomeBannerLive, []}
          ],
          secondary: [
            {Bonfire.UI.Social.WidgetTimelinesLive, [page: "federation"]},
            {Bonfire.UI.Social.WidgetTagsLive , []}
          ]
        ]
      ]
    ]
  end

  def instance_feed_assigns(socket_or_opts) do
    feed_id = Bonfire.Social.Feeds.named_feed_id(:local)
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket_or_opts)

    [
      current_user: current_user(socket_or_opts),
      selected_tab: "instance",
      page_title: l("Local activities"),
      page: "local",
      feed_title: l("Activities on this instance"),
      feed_id: feed_id,
      feed: e(feed, :edges, []),
      page_info: e(feed, :page_info, []), #|> IO.inspect
      # FIXME: seems too much re-assigning the whole sidebar widgets only to change the page prop?
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Common.HomeBannerLive, []}
          ],
          secondary: [
            {Bonfire.UI.Social.WidgetTimelinesLive, [page: "local"]},
            {Bonfire.UI.Social.WidgetTagsLive , []}
          ]
        ]
      ]
    ]
  end


end
