defmodule Bonfire.UI.Social.WidgetMessagesLive do
  use Bonfire.Web, :stateful_component

  def update(assigns, socket) do
    pagination = %{
        limit: 3
      }
    current_user = current_user(assigns)
    feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, nil, paginate: pagination) #|> IO.inspect
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
