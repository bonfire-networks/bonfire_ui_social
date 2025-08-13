defmodule Bonfire.UI.Social.Activity.VideoLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive
  alias Bonfire.Common.Media

  prop media, :map, default: nil
  prop metadata, :any, default: nil

  prop showing_within, :atom, default: nil
  prop parent_id, :any, default: nil

  prop muted, :boolean, default: false
  prop autoplay, :any, default: false
  prop media_label, :any, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
