defmodule Bonfire.UI.Social.EditCircleLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    circle = Bonfire.Me.Users.Circles.get(assigns.id, e(assigns, :current_user, nil)) |> repo().maybe_preload(encircles: [:subject_profile, :subject_character]) |> IO.inspect

    followed = Bonfire.Social.Follows.list_followed(e(assigns, :current_user, nil), e(assigns, :current_user, nil)) #|> IO.inspect
    followers = Bonfire.Social.Follows.list_followers(e(assigns, :current_user, nil), e(assigns, :current_user, nil)) #|> IO.inspect

    {:ok, assign(socket, assigns
    |> assigns_merge(%{circle: circle, follows: followers ++ followed}))}
  end
end
