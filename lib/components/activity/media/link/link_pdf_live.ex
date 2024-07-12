defmodule Bonfire.UI.Social.Activity.LinkPdfLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop media_url, :string, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
