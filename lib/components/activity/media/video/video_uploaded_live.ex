defmodule Bonfire.UI.Social.Activity.VideoUploadedLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop metadata, :any, default: nil
  prop showing_within, :atom, default: nil
  prop muted, :boolean, default: false
  prop autoplay, :any, default: false
  prop parent_id, :any, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
