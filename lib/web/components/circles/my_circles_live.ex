defmodule Bonfire.UI.Social.MyCirclesLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    circles = Bonfire.Me.Users.Circles.list_my(e(assigns, :current_user, nil)) |> IO.inspect

    {:ok, assign(socket, %{circles: circles})}
  end
end
