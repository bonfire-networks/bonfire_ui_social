defmodule Bonfire.UI.Social.WidgetUsersLive do
  use Bonfire.Web, :stateless_component

  prop users, :any

  def users(users) when is_list(users) do
    users
  end
  def users(%{edges: users}) when is_list(users) do
    users
  end
  def users(_) do
    admins()
  end

  def admins() do
    Bonfire.Me.Users.list_admins()
    |> Bonfire.Repo.maybe_preload([:character, profile: :icon])
  end

end
