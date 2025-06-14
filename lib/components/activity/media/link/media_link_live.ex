defmodule Bonfire.UI.Social.Activity.MediaLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop download_url, :string, default: nil
  prop preview_img, :string, default: nil
  prop media_url, :string, default: nil
  prop cw, :any, default: nil
  prop css_borders, :css_class, default: nil
  prop small_icon, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop parent_id, :any, default: nil
  prop activity_inception, :boolean, default: false

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
