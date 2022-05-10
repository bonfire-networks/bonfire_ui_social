defmodule Bonfire.UI.Social.WidgetNotificationLive do
  use Bonfire.UI.Common.Web, :stateful_component

  def update(assigns, socket) do
    current_user = current_user(assigns)
    paginate = %{
        limit: 3
      }
    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: current_user, paginate: paginate)
    {:ok, socket
      |> assign(
        feed: e(feed, :edges, []),
        feed_id: :widget_notifications,
        page_info: e(feed, :page_info, []),
        current_user: current_user,
        showing_within: :widget,
        feed_update_mode: "prepend",
        hide_load_more: true
      )
    }
  end

end
