defmodule Bonfire.UI.Social.Activity.AudioLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, required: true
  prop media_label, :string, default: nil

  prop muted, :boolean, default: false
  prop autoplay, :boolean, default: true

  prop parent_id, :any, default: nil
  prop showing_within, :atom, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
