defmodule Bonfire.UI.Social.WidgetTagsLive do
  use Bonfire.Web, :stateful_component

  def update(assigns, socket) do
    # pagination = %{
    #     limit: 3
    #   }
    # current_user = current_user(assigns)
    # feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, nil, paginate: pagination) #|> IO.inspect
    {:ok, socket}
  end

end
