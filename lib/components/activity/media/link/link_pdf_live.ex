defmodule Bonfire.UI.Social.Activity.LinkPdfLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop media_url, :string, default: nil
  prop css_borders, :css_class, default: nil
  prop parent_id, :any, default: nil
  prop showing_within, :atom, default: nil

  def update(_assign, socket) do
    {:noreply, socket}
  end
end
