defmodule Bonfire.UI.Social.Activity.MediaLinkLive do
  @moduledoc """
  Component for displaying media links with flexible layout options.

  ## Display Modes:
  - Full cover: Large preview image with vertical layout (default for single links with preview)
  - Small icon: 130x130 compact preview with horizontal layout (for multiple links or widgets)
  - No preview: Text-only with optional favicon fallback when no preview image is available

  ## Layout Logic:
  - `small_icon` or `activity_inception` → horizontal layout with small preview (if available)
  - Single link with preview → vertical layout with full cover
  - Multiple links → automatically use small icon mode for compact display
  - No preview image → text-only display with favicon fallback in dedicated section
  """
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil
  prop download_url, :string, default: nil
  prop preview_img, :string, default: nil
  prop media_url, :string, default: nil
  prop cw, :any, default: nil
  prop css_borders, :css_class, default: nil
  # Show compact 130x130 preview instead of full cover
  prop small_icon, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop parent_id, :any, default: nil
  # Hide preview image completely (use favicon or fallback icon)
  prop no_cover, :boolean, default: false
  # Force horizontal layout (used in thread inception context)
  prop activity_inception, :boolean, default: false

  def update(assigns, socket) do
    {:noreply, assign(socket, assigns)}
  end
end
