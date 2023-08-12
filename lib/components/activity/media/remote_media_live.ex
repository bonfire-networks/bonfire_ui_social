defmodule Bonfire.UI.Social.Activity.RemoteMediaLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.Activity.MediaLive

  prop media, :map, default: nil

  prop video_css, :css_class,
    default:
      "inline-block min-h-[350px] max-h-[90%] min-h-[300px] max-w-[96%] rounded-box border border-base-content/10"

  # prop type, :any, default: nil
end
