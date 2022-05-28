defmodule Bonfire.Social.Objects.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where
  alias Bonfire.Social.Objects

  def handle_event("set_name", %{"id" => id, "name" => name} = params, socket) do
    with {:ok, _} <- Objects.set_name(id, name, current_user: current_user(socket)) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign(page_title: name)
        |> assign_flash(:info, l "Name updated!")
      }
    end
  end

  def handle_event("delete", %{"id"=> id} = params, socket) do
    with {:ok, _} <- Objects.delete(id, current_user: current_user(socket)) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign_flash(:info, l "Deleted!")
      }
    end
  end

end
