defmodule Bonfire.UI.Social.FollowersLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    followers = Bonfire.Social.Follows.list_followers(e(assigns, :user, nil), e(assigns, :current_user, nil)) #|> IO.inspect

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      followers: followers,
      } ) ) }
  end
end
