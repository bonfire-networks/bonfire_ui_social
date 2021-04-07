defmodule Bonfire.UI.Social.MyCirclesLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do
    circles = Bonfire.Me.Users.Circles.list_my(e(assigns, :current_user, nil)) |> IO.inspect
    IO.inspect(circles, label: "Circles:")
    {:ok, assign(socket,
    %{
      circles: circles,
      settings_section_title: "Create and manage your circles",
      settings_section_description: "Create and manage your circles."
      })}
  end
end
