defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Social.ActivityLive

  import Where

  prop feed_id, :string
  prop feed, :list
  prop page_info, :map
  prop showing_within, :any
  prop feed_update_mode, :string, default: "prepend"
  prop hide_load_more, :boolean, default: false
  prop verb_default, :string

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
            # |> preloads(current_user: current_user(socket), skip_boundary_check: true)
    )
    }
  end

  def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) when is_map(new_activity) do
    debug("FeedLive: add new activity from component context")
    update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  end

  def update(%{feed: feed, page_info: page_info} =assigns, socket) when is_list(feed) do
    debug("FeedLive: a feed was provided")
    socket = assign(socket, assigns)

    {:ok, socket
    |> assign(
      feed: feed
      #|> debug("FeedLive: feed")
      |> preloads(current_user: current_user(socket), skip_boundary_check: true),
      page_info: page_info
      )}
  end

  def update(assigns, socket) do
    debug("FeedLive: feed NOT provided, try fetching one via Bonfire.Social")
    socket = assign(socket, assigns)
    current_user = current_user(socket)

    assigns = if module_enabled?(Bonfire.Social.Web.Feeds.HomeLive), do: Bonfire.Social.Feeds.LiveHandler.default_feed_assigns(socket),
    else: []

    # debug(assigns: assigns)

    {:ok, socket
    |> assign(
      feed: e(assigns, :feed, [])
      # |> debug("FeedLive: feed")
      |> preloads(current_user: current_user, skip_boundary_check: true)
    )}
  end

  # def handle_info({:new_activity, data}, socket) do
  #   debug(feed_live_pubsub_received: data)

  #   # send_update(Bonfire.UI.Social.FeedLive, id: "feed", new_activity: data)

  #   {:noreply, socket}
  # end

  def preloads(feed, opts) do
    debug("FeedLive: preload objects")

    if is_list(feed) and length(feed) > 0 do
      case List.first(feed) do

        %{activity: %{id: _}} ->
          feed
          # |> debug("feed of FeedPublish or objects before extra preloads")
          |> repo().maybe_preload(activity: [:media])
          |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([activity: [:object]])
          |> preload_objects([:activity, :object], opts)
          # |> debug("feed with extra preloads")

        %{edge: %{id: _}} ->
          feed
          # |> debug("feed of Edge objects before extra preloads")
          |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([edge: [:object]])
          |> preload_objects([:edge, :object], opts)
          # |> debug("feed with extra preloads")

        %{object: _} ->
          feed
          # |> debug("feed of activities before extra preloads")
          |> repo().maybe_preload(:media)
          |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([:object])
          |> preload_objects([:object], opts)
          # |> debug("feed with extra preloads")

        _ -> feed
      end

    else
      feed
    end
  end

  def preload_objects(feed, under, opts) do
    repo().maybe_preloads_per_nested_schema(feed, under, object_preloads(), opts)
  end

  def object_preloads do
    [
      {Bonfire.Data.Identity.User, Bonfire.UI.Social.Activity.CharacterLive.preloads()},
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()},
    ]
    # |> debug("preload feed")
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
