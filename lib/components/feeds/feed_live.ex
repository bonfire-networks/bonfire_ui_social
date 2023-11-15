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
  prop subject_user, :any, default: nil
  prop page_info, :any, default: nil
  prop previous_page_info, :any, default: nil
  prop loading, :boolean, default: true
  prop preload, :atom, default: :feed

  prop feedback_title, :string, default: nil
  prop feedback_message, :string, default: nil
  prop showing_within, :atom, default: nil
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string, default: nil

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
  prop top_page, :any, default: nil

  prop tabs_class, :css_class, default: nil

  prop tab_class, :css_class,
    default:
      "flex flex-1 pt-4 text-base capitalize hover:bg-base-content hover:bg-opacity-10 place-content-center lined_tab"

  prop item_class, :css_class,
    default: "text-base-content/60 text-sm pb-3 border-b-4 border-transparent font-medium"

  prop tab_primary_class, :css_class, default: nil

  prop sort_by, :any, default: nil
  prop time_limit, :any, default: nil
  prop sort_order, :any, default: false

  prop activity_loaded_preloads, :list, default: []

  slot bottom_or_empty_feed

  def mount(socket) do
    # FIXME: assigns not available in mount
    # feed_id = e(socket.assigns, :feed_name, nil) || e(socket.assigns, :feed_id, nil) || e(socket.assigns, :id, nil)

    {
      :ok,
      socket
      |> stream_configure(:feed, dom_id: &stream_id("feed", &1))
      |> stream(:feed, [])
      |> assign(
        feed: nil,
        hide_activities: nil,
        feed_count: nil,
        hide_fresh: 0
      )
      #  temporary_assigns: [
      #    feed: []
      #  ]
    }
  end

  defp stream_id(feed_id, entry) do
    "#{feed_id}_#{id(entry) || e(entry, :activity, :id, nil) || e(entry, :object, :id, nil) || e(entry, :edge, :id, nil) || Text.random_string()}"
  end

  # consolidate different kinds of lists/feeds into Activity
  defp get_activity(%{activity: %{id: _} = activity, edge: %{id: _} = edge}),
    do: merge_structs_as_map(activity, edge) |> debug("merged_structs_as_map")

  defp get_activity(%{edge: %{id: _, activity: %{id: _} = activity} = edge}),
    do: merge_structs_as_map(activity, edge) |> debug("merged_structs_as_map")

  defp get_activity(%{activity: %{id: _} = activity}), do: activity
  defp get_activity(%{edge: %{id: _} = activity}), do: activity
  defp get_activity(activity), do: activity

  def tabs(page, context) do
    # disabled hiding of remote tab because it is also useful to find remote activities that were looked up manually
    # case Bonfire.Social.Integration.federating?(current_user(context)) do
    #   true ->
    if current_user_id(context) do
      # if page == "home",
      #   do: [
      #     nil: l("My feed"),
      #     explore: l("Everything"),
      #     local: l("Local"),
      #     fediverse: l("Remote")
      #   ],
      #   else: 
      [explore: l("Everything"), local: l("Local"), fediverse: l("Remote")]

      # if context[:current_params]["object_type"] in ["discussions", "posts"],
      #   do: [nil: l("My feed"), local: l("Local"), fediverse: l("Remote")],
      #   else:
      #     if(!Bonfire.Boundaries.can?(context, :mediate, :instance),
      #       do: [
      #         nil: l("My feed"),
      #         local: l("Local"),
      #         fediverse: l("Remote"),
      #         likes: l("Liked")
      #       ],
      #       else: [
      #         nil: l("My feed"),
      #         local: l("Local"),
      #         fediverse: l("Remote"),
      #         likes: l("Liked"),
      #         flags: l("Flags")
      #       ]
      #     )
    else
      [explore: l("Everything"), local: l("Local"), fediverse: l("Remote")]
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
    |> LiveHandler.insert_feed(entries, reset: assigns[:reset_stream])
    |> ok_socket()
  end

  # adding new feed item
  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do
    debug("new_activity, add to top of feed")

    {
      :ok,
      socket
      |> assign(hide_fresh: e(socket.assigns, :hide_fresh, 0) + 1)
      # what an ugly way but idk
      |> push_event("js-exec-attr-event", %{
        to: "#show_fresh",
        attr: "phx-show"
      })
      |> LiveHandler.insert_feed(new_activity, at: 0, reset: false)
      #  |> JS.show(to: "#show_fresh") # LV doesn't have this for some reason
    }
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
      |> LiveHandler.feed_assigns_maybe_async(
        assigns[:feed_name] || socket.assigns[:feed_name] || socket.assigns[:feed_id] ||
          assigns[:feed_id] || assigns[:id] || socket.assigns[:id] || :default,
        ...
      )
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
      |> LiveHandler.feed_assigns_maybe_async(
        assigns[:feed_name] || socket.assigns[:feed_name] || socket.assigns[:feed_id] ||
          assigns[:feed_id] || assigns[:id] || socket.assigns[:id] || :default,
        ...
      )
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

  # def do_handle_event("select_tab", attrs, socket) do
  #   tab = maybe_to_atom(e(attrs, "name", nil))

  #   debug(attrs, tab)

  #   {:noreply,
  #    socket
  #    |> assign(selected_tab: tab)
  #    |> LiveHandler.insert_feed(LiveHandler.feed_assigns_maybe_async(tab, socket))}
  # end

  def widgets(assigns) do
    [
      sidebar_widgets: [
        users: [
          secondary: [
            {Bonfire.UI.Social.WidgetFeedLive,
             [
               event_target: "##{e(assigns, :feed_component_id, nil)}",
               feed_name: e(assigns, :feed_name, nil),
               sort_by: e(assigns, :sort_by, nil),
               time_limit: e(assigns, :time_limit, nil),
               sort_order: e(assigns, :sort_order, nil),
               showing_within: e(assigns, :showing_within, nil)
             ]},
            {Bonfire.Tag.Web.WidgetTagsLive, []}
          ]
        ]
      ]
    ]
  end

  def do_handle_event(
        "set",
        attrs,
        socket
      ) do
    # debug(attrs)
    # need to reload feed so streams are updated

    socket =
      socket
      # |> assign( replies: [])
      |> Bonfire.UI.Common.LiveHandlers.assign_attrs(attrs)

    send_self(widgets(e(socket, :assigns, nil)))

    {
      :noreply,
      socket
      # |> assign( replies: [])
      # |> Bonfire.UI.Common.LiveHandlers.assign_attrs(attrs)
      # |> assign(:page_header_aside, LiveHandler.page_header_asides(...))
      |> LiveHandler.insert_feed(
        ...,
        LiveHandler.feed_assigns_maybe_async(
          socket.assigns[:feed_name] || socket.assigns[:feed_id] || socket.assigns[:id] ||
            :default,
          ...,
          true,
          true
        )
      )
      # |> debug("seeet")
    }
  end

  #   def handle_event(
  #       "hide_fresh",
  #       attrs,
  #       socket
  #     )do

  #   {:ok,
  #    socket
  #    |> assign(
  #      hide_fresh: 0
  #    )}
  # end

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
