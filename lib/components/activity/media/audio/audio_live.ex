defmodule Bonfire.UI.Social.Activity.AudioLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, required: true
  prop is_video?, :boolean, default: false
  prop media_label, :string, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
