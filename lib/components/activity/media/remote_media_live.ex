defmodule Bonfire.UI.Social.Activity.RemoteMediaLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil

  prop muted, :boolean, default: false
  prop autoplay, :boolean, default: true

  prop base_css, :css_class, default: "max-h-screen max-w-screen w-full"

  # prop block_css, :css_class, default: [@default, "min-w-[400px] min-h-[260px] h-full"]

  prop base_image_css, :css_class,
    default: "max-h-[calc(var(--inner-window-height)_-_150px)] relative mx-auto"

  prop image_css, :css_class, default: ""

  prop video_css, :css_class,
    default: "w-full h-full inline-block rounded-box border border-base-content/20"

  # prop type, :any, default: nil
end
