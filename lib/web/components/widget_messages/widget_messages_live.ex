defmodule Bonfire.UI.Social.WidgetMessagesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string

  def feed(assigns) do
    paginate = %{
        limit: 3
      }
    current_user = current_user(assigns)
    feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, nil, paginate: paginate) #|> IO.inspect
    e(feed, :edges, nil)
  end

end
