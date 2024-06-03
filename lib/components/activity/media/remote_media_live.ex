defmodule Bonfire.UI.Social.Activity.RemoteMediaLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  @default "max-h-screen max-w-screen w-full"

  prop media, :map, default: nil

  prop default_css, :css_class, default: @default

  prop block_css, :css_class, default: [@default, "min-w-[400px] min-h-[260px] h-full"]

  prop video_css, :css_class,
    default: [@default, "w-full h-full", "inline-block rounded-box border border-base-content/10"]

  # prop type, :any, default: nil
end
