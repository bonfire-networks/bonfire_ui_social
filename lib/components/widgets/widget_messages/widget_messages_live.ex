defmodule Bonfire.UI.Social.WidgetMessagesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  def render(assigns) do
    assigns
    |> assign_new(:feed, fn -> feed(current_user(assigns)) end)
    |> render_sface()
  end

  def feed(current_user) do
    paginate = %{
      limit: 3
    }

    # |> IO.inspect
    feed =
      if current_user,
        do:
          if(module_enabled?(Bonfire.Messages, current_user),
            do: Bonfire.Messages.list(current_user, nil, paginate: paginate)
          )

    e(feed, :edges, nil)
  end
end
