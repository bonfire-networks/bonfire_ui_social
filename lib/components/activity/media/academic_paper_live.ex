defmodule Bonfire.UI.Social.Activity.AcademicPaperLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil

  def update(assign, socket) do
    debug(socket.assigns.media, "CACCA")
    {:noreply, socket}
  end
end
