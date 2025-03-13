defmodule Bonfire.UI.Social.Activity.VideoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop metadata, :map, default: nil
  prop showing_within, :atom, default: nil
  prop muted, :boolean, default: false
  prop autoplay, :boolean, default: true
  prop media_label, :any, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
