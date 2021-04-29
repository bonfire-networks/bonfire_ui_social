defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.Web, :live_component
  alias Bonfire.UI.Social.ActivityLive


  def update(%{feed: feed} =assigns, socket) when is_list(feed) do

    {:ok, socket
    |> assigns_merge(assigns, %{
      }) }
  end


  def update(assigns, socket) do
    IO.inspect("default to instance feed as none other was specified")

    feed_id = Bonfire.Social.Feeds.instance_feed_id()

    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket)

    title = e(assigns, :feed_title, "Recent activity on this instance")

    {:ok, socket
    |> assigns_merge( assigns,
      feed_title: title,
      feed_id: feed_id,
      feed: e(feed, :entries, []),
      page_info: e(feed, :metadata, [])
    )}
  end


end
