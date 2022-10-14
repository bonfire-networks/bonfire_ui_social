defmodule Bonfire.UI.Social.WidgetMessagesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  def feed(current_user) do
    paginate = %{
      limit: 3
    }

    # |> IO.inspect
    feed =
      if current_user,
        do:
          if(module_enabled?(Bonfire.Social.Messages, current_user),
            do: Bonfire.Social.Messages.list(current_user, nil, paginate: paginate)
          )

    e(feed, :edges, nil)
  end
end
