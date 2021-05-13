defmodule  Bonfire.UI.Social.BrowseViewLive do
  use Bonfire.Web, :live_component

  def update(%{feed: feed} =assigns, socket) when is_list(feed) and length(feed)>0 do

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      })) }
  end


  def update(%{current_user: %{id: _user_id} = current_user} = assigns, socket) when not is_nil(current_user) do
    IO.inspect("default to my feed if none other was provided and we're logged in")

    feed = Bonfire.Social.FeedActivities.my_feed(current_user) #|> IO.inspect

    {:ok, socket
      |> assigns_merge(assigns,
        feed: e(feed, :entries, []),
        page_info: e(feed, :metadata, [])
    )}
  end

  def update(assigns, socket) do
    IO.inspect("default to instance feed if none other was provided and we're not logged in")

    feed_id = Bonfire.Social.Feeds.instance_feed_id()
    feed = Bonfire.Social.FeedActivities.feed(feed_id, socket)

    {:ok, socket
      |> assigns_merge(assigns,
        feed: e(feed, :entries, []),
        page_info: e(feed, :metadata, [])
    )}
  end
end
