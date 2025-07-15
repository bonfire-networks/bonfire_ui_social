defmodule Bonfire.UI.Social.Activity.RemoteMediaLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive
  alias Bonfire.UI.Common.MediaPlayerLive

  prop media, :map, default: nil
  prop parent_id, :any, default: nil

  prop muted, :boolean, default: false
  prop autoplay, :any, default: true

  prop base_css, :css_class, default: "max-w-screen w-full"

  # prop block_css, :css_class, default: [@default, "min-w-[400px] min-h-[260px] h-full"]

  prop base_image_css, :css_class,
    default: "max-h-[calc(var(--inner-window-height)_-_150px)] relative mx-auto"

  prop image_css, :css_class, default: ""

  prop video_css, :css_class,
    default: "h-full inline-block rounded-box border border-base-content/10"

  # prop type, :any, default: nil
end
