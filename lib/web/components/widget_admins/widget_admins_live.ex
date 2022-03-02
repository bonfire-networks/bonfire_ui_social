defmodule Bonfire.UI.Social.WidgetAdminsLive do
  use Bonfire.Web, :stateful_component

  def update(assigns, socket) do
    admins = Bonfire.Me.Users.list_admins()
    |> Bonfire.Repo.maybe_preload([:character, :profile])
    IO.inspect(admins, label: "ADMINS")
    {:ok, socket
      |> assign(
        admins: admins
      )
    }
  end

end