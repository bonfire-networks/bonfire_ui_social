defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler

  import Untangle

  prop feed_name, :atom, default: nil
  prop feed_id, :any, default: nil
  prop feed_ids, :any, default: nil
  prop feed_filters, :any, default: []
  prop feed, :any, default: []
  prop page_info, :any, default: nil
  prop loading, :boolean, default: true
  prop preload, :atom, default: :feed

  prop feedback_title, :string, default: nil
  prop feedback_message, :string, default: nil
  prop showing_within, :atom, default: nil
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string, default: nil

  prop page, :string, default: nil
  prop page_title, :string, required: true
  prop feed_title, :string, default: nil

  @doc "What LiveHandler and/or event name to send the patch event to for tabs navigation (if any)"
  # "select_tab"
  prop event_handler, :string, default: nil
  # FIXME: should optimise by LinkPatchLive but currently not working
  prop tab_link_component, :atom, default: LinkLive

  prop tab_path_prefix, :string, default: "?tab="
  prop tab_path_suffix, :string, default: nil
  prop hide_tabs, :boolean, default: false
  prop selected_tab, :any, default: nil

  prop tabs_class, :css_class
  prop tab_class, :css_class
  prop tab_primary_class, :css_class, default: nil

  slot bottom_or_empty_feed

  def mount(socket) do
    feed_id =
      e(socket.assigns, :feed_name, nil) || e(socket.assigns, :feed_id, nil) ||
        e(socket.assigns, :id, nil)

    {
      :ok,
      socket
      |> stream_configure(:feed, dom_id: &component_id(feed_id, &1))
      |> stream(:feed, [])
      |> assign(
        feed: nil,
        hide_activities: nil,
        feed_count: nil
      )
      #  temporary_assigns: [
      #    feed: []
      #  ]
    }
  end

  defp component_id(feed_id, entry) do
    "#{feed_id}_#{id(entry) || e(entry, :activity, :id, nil) || e(entry, :object, :id, nil) || e(entry, :edge, :id, nil) || Pointers.ULID.generate()}"
  end

  # consolidate different kinds of lists/feeds into Activity
  defp get_activity(%{activity: %{} = activity, edge: %{} = edge}),
    do: merge_structs_as_map(activity, edge)

  defp get_activity(%{activity: %{id: _} = activity}), do: activity
  defp get_activity(%{edge: %{} = activity}), do: activity
  defp get_activity(activity), do: activity

  def tabs(current_user, object_type) do
    # disabled hiding of remote tab because it is also useful to find remote activities that were looked up manually
    # case ActivityPub.Config.federating?() do
    #   true ->
    if not is_nil(current_user) do
      if object_type in ["discussions", "posts"],
        do: [nil: l("My feed"), local: l("Local"), fediverse: l("Remote")],
        else:
          if(!Bonfire.Me.Users.is_admin?(current_user),
            do: [
              nil: l("My feed"),
              local: l("Local"),
              fediverse: l("Remote"),
              likes: l("Liked")
            ],
            else: [
              nil: l("My feed"),
              local: l("Local"),
              fediverse: l("Remote"),
              likes: l("Liked"),
              flags: l("Flags")
            ]
          )
    else
      [local: l("Local"), fediverse: l("Remote")]
    end

    #   _ ->
    #     if not is_nil(current_user) do
    #       if object_type in ["discussions", "posts"],
    #         do: [nil: l("My feed"), local: l("Local")],
    #         else: [nil: l("My feed"), local: l("Local"), likes: l("Liked")]
    #     else
    #       [local: l("Local")]
    #     end
    # end
  end

  def update(%{insert_stream: %{feed: entries}} = assigns, socket) do
    debug("feed stream is being poured into")

    socket
    |> assign(Map.drop(assigns, [:insert_stream]))
    |> LiveHandler.insert_feed(entries)
    |> ok_socket()
  end

  # adding new feed item
  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do
    debug("new_activity (feed is a temporary assign, so only add new activities)")

    {:ok,
     socket
     |> assign(
       feed_update_mode: "prepend",
       feed: [new_activity]
     )}
  end

  # def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
  #   debug("FeedLive: add new activity from component context")
  #   update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  # end

  def update(_assigns, %{assigns: %{loading: loading?, feed: feed}} = socket)
      when loading? == false and feed != :loading do
    debug("skip replacing feed unless it was loading")
    ok_socket(socket)
  end

  def update(_assigns, %{assigns: %{feed: existing_feed}} = socket)
      when is_list(existing_feed) and length(existing_feed) > 0 do
    # FIXME: doesn't work because of temporary assigns?
    debug("skip replacing already loaded feed")
    ok_socket(socket)
  end

  def update(%{feed: feed, page_info: _page_info} = assigns, socket) when is_list(feed) do
    debug("an initial feed was provided via assigns")
    debug(assigns)

    # debug(socket.assigns, "socket assigns")
    # debug(assigns)
    socket = assign(socket, assigns)
    # debug(socket)

    feed_id_or_ids = e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :feed_id, nil)
    already_pubsub_subscribed = e(socket.assigns, :feed_pubsub_subscribed, nil)

    if already_pubsub_subscribed == feed_id_or_ids do
      debug(already_pubsub_subscribed, "already subscribed to this via pubsub")
    else
      maybe_subscribe(socket)
    end

    ok_socket(
      socket
      |> assign(
        feed_pubsub_subscribed: feed_id_or_ids
        # page_info: page_info,
        # feed: feed
        # |> debug("FeedLive: feed")
      )
    )
  end

  def update(%{feed_id: "user_timeline_"} = assigns, socket) do
    debug("a user feed was NOT provided, fetching one now")

    socket = assign(socket, assigns)

    socket =
      socket
      |> assign(feed_component_id: socket.assigns.id)
      |> LiveHandler.feed_assigns_maybe_async(assigns[:id] || :default, ...)
      |> LiveHandler.insert_feed(socket, ...)

    maybe_subscribe(socket)

    {:ok, socket}
  end

  def update(%{feed: nil} = assigns, socket) do
    debug("a feed was NOT provided, fetching one now")

    socket = assign(socket, assigns)

    socket =
      socket
      |> assign(feed_component_id: socket.assigns.id)
      |> LiveHandler.feed_assigns_maybe_async(assigns[:feed_id] || assigns[:id] || :default, ...)
      |> LiveHandler.insert_feed(socket, ...)

    maybe_subscribe(socket)

    {:ok, socket}
  end

  def update(%{feed: :loading} = assigns, socket) do
    debug("a feed is being loaded async")

    ok_socket(assign(socket, assigns))
  end

  def update(%{loading: true} = assigns, socket) do
    debug("a feed is being loaded async")

    ok_socket(assign(socket, assigns))
  end

  def update(_assigns, socket) do
    warn("No feed loaded")
    {:ok, socket}
  end

  defp ok_socket(socket) do
    # debug(socket.assigns[:__context__][:current_params], "fsa")

    {:ok,
     socket
     |> assign(
       feed_component_id: socket.assigns.id,
       hide_activities: socket.assigns[:__context__][:current_params]["hide_activities"]
     )}
  end

  def maybe_subscribe(socket) do
    case e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :feed_id, nil) do
      nil -> debug("no feed_id known, not subscribing to live updates")
      feed_or_feeds -> PubSub.subscribe(feed_or_feeds, socket)
    end
  end

  # def handle_info({:new_activity, data}, socket) do
  #   debug(feed_live_pubsub_received: data)

  #   # maybe_send_update(Bonfire.UI.Social.FeedLive, "feed", new_activity: data)

  #   {:noreply, socket}
  # end

  def do_handle_event("select_tab", attrs, socket) do
    tab = maybe_to_atom(e(attrs, "name", nil))

    debug(attrs, tab)

    {:noreply,
     socket
     |> assign(selected_tab: tab)
     |> Bonfire.Social.Feeds.LiveHandler.insert_feed(
       LiveHandler.feed_assigns_maybe_async(tab, socket)
     )}
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__,
          &do_handle_event/3
        )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
