defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.Web, :stateful_component
  alias Bonfire.UI.Social.ActivityLive

  require Logger

  prop feed, :list
  prop page_info, :map
  prop showing_within, :any

  def mount(socket) do
    {:ok, socket
    |> assign(
      feed: [],
    ),
    temporary_assigns: [
      feed: [],
      # feed_future: []
    ]}
  end


  def update(%{new_activity: new_activity} = _assigns, socket) when is_map(new_activity) do # adding new feed item
    Logger.debug("FeedLive - new_activity (feed is a temporary assign, so only add new activities)")
    {:ok, socket
    |> assign(
      feed_update_mode: "prepend",
      feed: [new_activity]
            # |> preloads(current_user: current_user(socket), skip_boundary_check: true)
    )
    }
  end

  def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
    Logger.debug("FeedLive: add new activity from component context")
    update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  end

  def update(%{feed: feed, page_info: page_info} =assigns, socket) when is_list(feed) do
    Logger.debug("FeedLive: a feed was provided")
    socket = assign(socket, assigns)

    {:ok, socket
    |> assign(
      feed: feed
      #|> IO.inspect(label: "FeedLive: feed")
      |> preloads(current_user: current_user(socket), skip_boundary_check: true),
      page_info: page_info
      )}
  end

  def update(assigns, socket) do
    Logger.debug("FeedLive: feed NOT provided, try fetching one via Bonfire.Social")
    socket = assign(socket, assigns)
    current_user = current_user(socket)

    assigns = if module_enabled?(Bonfire.Social.Web.Feeds.BrowseLive), do: Bonfire.Social.Web.Feeds.BrowseLive.default_feed(socket),
    else: []

    # IO.inspect(assigns: assigns)

    {:ok, socket
    |> assign(
      feed: e(assigns, :feed, [])
      # |> IO.inspect(label: "FeedLive: feed")
      |> preloads(current_user: current_user, skip_boundary_check: true)
    )}
  end

  # def handle_info({:new_activity, data}, socket) do
  #   IO.inspect(feed_live_pubsub_received: data)

  #   # send_update(Bonfire.UI.Social.FeedLive, id: "feed", new_activity: data)

  #   {:noreply, socket}
  # end

  def preloads(feed, opts) do
    Logger.debug("FeedLive: preload objects")

    feed
    |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([activity: [:object]])
    |> preload_objects(opts)
    # |> IO.inspect(label: "feed with extra preloads")
  end

  def object_preloads do
    [
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()},
    ]
    # |> IO.inspect(label: "preload feed")
  end

  def preload_objects(feed, opts) do
    repo().maybe_preloads_per_nested_schema(feed, [:activity, :object], object_preloads(), opts)
  end

  def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
