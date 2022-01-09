defmodule Bonfire.UI.Social.EditCircleLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

      with {:ok, circle} <- Bonfire.Me.Users.Circles.get(assigns.id, current_user(assigns)) |> repo().maybe_preload(encircles: [subject: [:profile, :character]]) do
        IO.inspect(circle)

      # TODO: paginate
      followed = Bonfire.Social.Follows.list_my_followed(current_user(assigns), false) #|> IO.inspect
      followers = Bonfire.Social.Follows.list_my_followers(current_user(assigns), false) #|> IO.inspect

      {:ok, assign(socket, assigns
      |> assigns_merge(%{circle: circle, followers: followers, followed:  followed}))}
    end
  end
end
