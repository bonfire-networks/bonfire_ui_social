defmodule Bonfire.UI.Social.WidgetNotificationLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string

  def load(current_user) do
    paginate = %{
      limit: 3
    }

    feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, current_user: current_user)

    feed =
      Bonfire.Social.FeedActivities.feed(:notifications,
        current_user: current_user,
        paginate: paginate
      )

    [
      id: :widget_notifications,
      feed: e(feed, :edges, []),
      feed_id: feed_id,
      page_info: e(feed, :page_info, []),
      current_user: current_user,
      showing_within: :widget,
      feed_update_mode: "prepend",
      hide_load_more: true
    ]
  end
end
