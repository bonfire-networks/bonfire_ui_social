defmodule Bonfire.UI.Social.WidgetNotificationLive do
  use Bonfire.Web, :stateful_component

  def update(assigns, socket) do
    pagination = %{
        limit: 1
      }
    feed = Bonfire.Social.FeedActivities.feed(:notifications, Map.put(assigns, :paginate, pagination))
    {:ok, socket
      |> assign(
        feed: e(feed, :edges, []),
        feed_id: :widget_notifications,
        page_info: e(feed, :page_info, []),
        current_user: current_user(assigns),
        showing_within: :widget,
        feed_update_mode: "replace"
      )
    }
  end

end