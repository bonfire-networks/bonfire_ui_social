defmodule  Bonfire.UI.Social.ObjectThreadLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

    participants = Bonfire.Social.Threads.list_participants(e(assigns, :object, :id, nil), e(assigns, :current_user, nil))
    |> IO.inspect

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
        page: "Discussion",
        date_ago: date_from_now(assigns.object),
        participants: participants
      })) }
  end


end
