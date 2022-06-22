defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.ActivityLive
  alias Bonfire.Social.Feeds.LiveHandler

  import Where

  prop feed_id, :string
  prop feed_ids, :any
  prop feed, :list
  prop page_info, :any
  prop feedback_title, :string
  prop feedback_message, :string
  prop showing_within, :any, default: nil
  prop feed_update_mode, :string, default: "append"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string
  prop loading, :boolean, default: false
  prop preload, :atom, default: :feed
  prop page, :string
  prop page_title, :string, required: true
  prop feed_title, :string

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
    debug("FeedLive - new_activity (feed is a temporary assign, so only add new activities)")
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

  def update(%{feed: feed, page_info: page_info} =assigns, socket) when is_list(feed) do
    debug("FeedLive: a feed was provided")
    # TODO: why do this in update rather than LV's preload?
    socket = assign(socket, assigns)

    maybe_subscribe(socket)

    {:ok, socket
    |> assign(
      page_info: page_info,
      feed: feed
        # |> dump("FeedLive: feed")
        |> LiveHandler.preloads(socket),
      )}
  end

  def update(assigns, socket) do
    error("FeedLive: a feed was NOT provided, try fetching one in a parent component")
    socket = assign(socket, assigns)

    # current_user = current_user(socket)

    # assigns = if module_enabled?(Bonfire.UI.Social.Feeds.HomeLive), do: Bonfire.Social.Feeds.LiveHandler.feed_assigns_maybe_async(:default, socket),
    # else: []
    # socket = assign(socket, assigns)

    # maybe_subscribe(socket)

    # debug(assigns: assigns)

    {:ok, socket
    # |> assign(
    #   feed: e(assigns, :feed, [])
    #     # |> debug("FeedLive: feed")
    #     |> LiveHandler.preloads(socket)
    #   )
    }
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
