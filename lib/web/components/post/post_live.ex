defmodule  Bonfire.UI.Social.PostLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do


    {:ok, assign(socket, assigns
    |> assigns_merge(%{
        date_ago: date_from_now(assigns.object),
      })) }
  end


end
