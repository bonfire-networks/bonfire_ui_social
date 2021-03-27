defmodule Bonfire.UI.Social.FollowersLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    followers = Bonfire.Social.Follows.list_followed(e(assigns, :user, nil), e(assigns, :current_user, nil)) #|> IO.inspect

    {:ok, assign(socket, %{follows: followers})}
  end
end
