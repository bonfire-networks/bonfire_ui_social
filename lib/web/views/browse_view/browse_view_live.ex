defmodule  Bonfire.UI.Social.BrowseViewLive do
  use Bonfire.Web, :live_component

  def update(%{feed: _} =assigns, socket) do

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      })) }
  end


  def update(%{current_user: %{id: user_id} = current_user} = assigns, socket) do # default to instance feed if none other was specified and we're logged in

    feed = Bonfire.Social.FeedActivities.my_feed(current_user)

    {:ok, socket
    |> assign(
      assigns
    |> assigns_merge(
      feed: e(feed, :entries, []),
      page_info: e(feed, :metadata, [])
    ))}
  end
end
