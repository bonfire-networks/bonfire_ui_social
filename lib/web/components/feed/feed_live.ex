defmodule Bonfire.UI.Social.FeedLive do
  use Bonfire.Web, :live_component
  alias Bonfire.UI.Social.ActivityLive

  def update(%{feed: _} =assigns, socket) do

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      })) }
  end


  def update(assigns, socket) do # default to instance feed if none other was specified
    feed_id = Bonfire.Social.Feeds.instance_feed_id()

    feed = Bonfire.Social.FeedActivities.feed(feed_id, e(socket.assigns, :current_user, nil))

    title = e(assigns, :feed_title, "Recent activity on this instance")

    {:ok, socket
    |> assign(
      assigns
    |> assigns_merge(
      feed_title: title,
      feed_id: feed_id,
      feed: e(feed, :entries, []),
      page_info: e(feed, :metadata, [])
    ))}
  end

end
