defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler

  import Untangle

  prop feed_id, :any, default: nil
  prop feed_ids, :any, default: nil
  prop feed_filters, :any, default: []
  prop feed, :any, default: nil
  prop page_info, :any, default: nil
  prop loading, :boolean, default: false
  prop preload, :atom, default: :feed

  prop feedback_title, :string, default: nil
  prop feedback_message, :string, default: nil
  prop showing_within, :any, default: :feed
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string, default: nil

  prop page, :string, default: nil
  prop page_title, :string, required: true
  prop feed_title, :string, default: nil

  @doc "What LiveHandler and/or event name to send the patch event to for tabs navigation (if any)"
  prop event_handler, :string, default: "select_tab"

  prop tab_path_prefix, :string, default: "?tab="
  prop hide_tabs, :boolean, default: false
  prop selected_tab, :any, default: nil

  prop tabs_class, :css_class,
    default: "flex justify-start gap-3 p-4 mb-3 rounded-md shadow tabs-boxed tabs bg-base-100"

  # slot hero

  def mount(socket) do
    {:ok,
     socket
     |> assign(feed: nil),
     temporary_assigns: [
       feed: []
       # feed_future: []
     ]}
  end

  defp get_activity(%{activity: %{} = activity, edge: %{} = edge}),
    do: merge_structs_as_map(activity, edge)

  defp get_activity(%{activity: %{} = activity}), do: activity
  defp get_activity(%{edge: %{} = activity}), do: activity
  defp get_activity(activity), do: activity

  # adding new feed item
  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do
    debug(
      "FeedLive.update - new_activity (feed is a temporary assign, so only add new activities)"
    )

    {:ok,
     socket
     |> assign(
       feed_update_mode: "prepend",
       feed:
         [new_activity]
         |> Bonfire.Social.Feeds.LiveHandler.preloads(socket)
     )}
  end

  # def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
  #   debug("FeedLive: add new activity from component context")
  #   update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  # end

  def update(_assigns, %{assigns: %{loading: false}} = socket) do
    debug("skip replacing already loaded feed")
    ok_socket(socket)
  end

  def update(_assigns, %{assigns: %{feed: existing_feed}} = socket)
      when is_list(existing_feed) and length(existing_feed) > 0 do
    # FIXME: doesn't work because of temporary assigns?
    debug("skip replacing already provided feed")
    ok_socket(socket)
  end

  def update(%{feed: feed, page_info: page_info} = assigns, socket) when is_list(feed) do
    debug("FeedLive.update - an initial feed was provided via assigns")
    debug(feed)

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
        # |> LiveHandler.preloads(socket),
      )
    )
  end

  def update(%{feed: nil} = assigns, socket) do
    debug("FeedLive.update - a feed was NOT provided, fetching one now")

    socket = assign(socket, assigns)

    socket =
      socket
      |> assign(feed_component_id: socket.assigns.id)
      |> Bonfire.Social.Feeds.LiveHandler.feed_assigns_maybe_async(:default, ...)
      |> assign_generic(socket, ...)

    maybe_subscribe(socket)

    {:ok, socket}
  end

  def update(%{feed: :loading} = assigns, socket) do
    debug("FeedLive.update - a feed is being loaded async")

    ok_socket(assign(socket, assigns))
  end

  def update(assigns, socket) do
    error("No feed loaded")
  end

  defp ok_socket(socket) do
    {:ok,
     socket
     |> assign(feed_component_id: socket.assigns.id)}
  end

  def maybe_subscribe(socket) do
    case e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :feed_id, nil) do
      nil -> debug("no feed_id known, not subscribing to live updates")
      feed_or_feeds -> pubsub_subscribe(feed_or_feeds, socket)
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
     |> assign_generic(LiveHandler.feed_assigns_maybe_async(tab, socket))}
  end

  def do_handle_event(action, attrs, socket) do
    debug(attrs, action)
    # poor man's hook I guess
    Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  end

  def handle_event(action, attrs, socket) do
    undead_params(socket, fn ->
      do_handle_event(action, attrs, socket)
    end)
  end

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
