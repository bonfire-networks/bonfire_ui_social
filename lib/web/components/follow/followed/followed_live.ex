defmodule Bonfire.UI.Social.FollowedLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    followed = Bonfire.Social.Follows.list_followed(e(assigns, :user, nil), e(assigns, :current_user, nil)) #|> IO.inspect

    {:ok, assign(socket, assigns
    |> assigns_merge(%{
      followed: followed
      })) }
  end
end
