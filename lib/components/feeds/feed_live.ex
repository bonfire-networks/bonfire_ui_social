defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler

  import Untangle

  prop feed_id, :string, default: nil
  prop feed_ids, :any, default: nil
  prop feed, :list
  prop page_info, :any
  prop feedback_title, :string, default: nil
  prop feedback_message, :string, default: nil
  prop showing_within, :any, default: :feed
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string, default: nil
  prop loading, :boolean, default: false
  prop preload, :atom, default: :feed
  prop page, :string, default: nil
  prop page_title, :string, required: true
  prop feed_title, :string, default: nil

  def mount(socket) do
    {:ok, socket
    |> assign(
      feed: []
    ),
    temporary_assigns: [
      feed: [],
      # feed_future: []
    ]}
  end

  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do # adding new feed item
    debug("FeedLive.update - new_activity (feed is a temporary assign, so only add new activities)")
    {:ok, socket
    |> assign(
      feed_update_mode: "prepend",
      feed: [new_activity]
            |> LiveHandler.preloads(socket)
      )
    }
  end

  # def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
  #   debug("FeedLive: add new activity from component context")
  #   update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  # end

  def update(_assigns, %{assigns: %{loading: false}} = socket) do
    debug("skip replacing already loaded feed")
    {:ok, socket}
  end

  def update(_assigns, %{assigns: %{feed: existing_feed}} = socket) when is_list(existing_feed) and length(existing_feed)>0 do
    # FIXME: doesn't work because of temporary assigns?
    debug("skip replacing already provided feed")
    {:ok, socket}
  end

  def update(%{feed: feed, page_info: page_info} = assigns, socket) when is_list(feed) do
    debug("FeedLive.update - an initial feed was provided via assigns")

    # dump(socket.assigns, "socket assigns")
    # dump(assigns)
    socket = assign(socket, assigns)
    # dump(socket)

    feed_id_or_ids = e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :feed_id, nil)
    already_pubsub_subscribed = e(socket.assigns, :feed_pubsub_subscribed, nil)

    if already_pubsub_subscribed == feed_id_or_ids do
      debug(already_pubsub_subscribed, "already subscribed to this via pubsub")
    else
      maybe_subscribe(socket)
    end

    {:ok, socket
      |> assign(
        feed_pubsub_subscribed: feed_id_or_ids,
        # page_info: page_info,
        # feed: feed
          # |> dump("FeedLive: feed")
          # |> LiveHandler.preloads(socket),
    )}
  end

  def update(assigns, socket) do
    error("FeedLive.update - a feed was NOT provided, try fetching one in a parent component")

    # current_user = current_user(socket)

    # assigns = if module_enabled?(Bonfire.UI.Social.Feeds.HomeLive), do: Bonfire.Social.Feeds.LiveHandler.feed_assigns_maybe_async(:default, socket),
    # else: []
    # socket = assign(socket, assigns)

    # maybe_subscribe(socket)

    # debug(assigns: assigns)

    {:ok, assign(socket, assigns)}
    # |> assign(
    #   feed: e(assigns, :feed, [])
    #     # |> debug("FeedLive: feed")
    #     |> LiveHandler.preloads(socket)
    #   )
  end

  def maybe_subscribe(socket) do
    case e(socket.assigns, :feed_ids, nil) || e(socket.assigns, :feed_id, nil) do
      nil -> debug("no feed_id known, not subscribing to live updates")
      feed_or_feeds -> pubsub_subscribe(feed_or_feeds, socket)
    end
  end

  # def handle_info({:new_activity, data}, socket) do
  #   debug(feed_live_pubsub_received: data)

  #   # send_update(Bonfire.UI.Social.FeedLive, id: "feed", new_activity: data)

  #   {:noreply, socket}
  # end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
