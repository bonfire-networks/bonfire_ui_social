defmodule Bonfire.UI.Social.Activity.VideoUploadedLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop metadata, :map, default: nil
  prop showing_within, :atom, default: nil
  prop is_video?, :boolean, default: true

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
