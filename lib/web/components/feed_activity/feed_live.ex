defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.Web, :live_component
  alias Bonfire.UI.Social.ActivityLive
  import Bonfire.UI.Social.Integration

  def mount(socket) do
    {:ok, socket
    |> assign(
      feed: [],
      feed_future: []
    ),
    temporary_assigns: [
      feed: [],
      feed_future: []
    ]}
  end


  def update(%{new_activity: new_activity} = assigns, socket) when is_map(new_activity) do # feed provided by parent component/view

    {:ok, socket
    |> assigns_merge(assigns,
      feed_future: [new_activity] # feed is a temporary assign, so only add new
      ) }
  end

  def update(%{__context__: %{new_activity: new_activity}} = assigns, socket) do # adding new feed item
    # IO.inspect(context_reply: new_activity)
    update(Map.merge(assigns, %{new_activity: new_activity}), socket)
  end

  def update(%{feed: feed} = assigns, socket) when is_list(feed) do # feed provided by parent component/view

    {:ok, socket
    |> assigns_merge(assigns,
      feed: preloads(feed),
      page_info: e(assigns, :page_info, e(socket, :assigns, :page_info, nil))
      ) }
  end

  def update(assigns, socket) do
    IO.inspect("default to instance feed as none other was specified")

    feed_id = Bonfire.Social.Feeds.instance_feed_id()

    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket)

    title = e(assigns, :feed_title, "Recent activity on this instance")

    {:ok, socket
    |> assigns_merge(assigns,
      feed_title: title,
      feed_id: feed_id,
      feed: preloads(e(feed, :entries, [])),
      page_info: e(feed, :metadata, []) #|> IO.inspect(label)
    )}
  end

  def preloads(feed) do
    # preloads = (
    #    Bonfire.UI.Social.Activity.EconomicEventLive.preloads()
    # ++ Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()
    # ++ Bonfire.UI.Social.Activity.IntentTaskLive.preloads()
    # ++ Bonfire.UI.Social.Activity.ProcessListLive.preloads()
    # )
    # # |> Enum.map(&[activity: [object: &1]])
    # |> IO.inspect(label: "preload feed")

    feed
    |> Bonfire.Common.Pointers.Preload.maybe_preload_nested_pointers([activity: [:object]])
    # |> repo().maybe_preload(preloads)
    |> preload_objects()
    # |> IO.inspect(label: "feed with extra preloads")
  end

  def preload_objects(feed) do

    preloads = [
      {ValueFlows.EconomicEvent, Bonfire.UI.Social.Activity.EconomicEventLive.preloads()},
      {ValueFlows.EconomicResource, Bonfire.UI.Social.Activity.EconomicResourceLive.preloads()},
      {ValueFlows.Planning.Intent, Bonfire.UI.Social.Activity.IntentTaskLive.preloads()},
      {ValueFlows.Process, Bonfire.UI.Social.Activity.ProcessListLive.preloads()},
    ]
    # |> Enum.map(&[activity: [object: &1]])
    # |> IO.inspect(label: "preload feed")

    repo().maybe_preloads_per_schema(feed, [:activity, :object], preloads)
  end

end
