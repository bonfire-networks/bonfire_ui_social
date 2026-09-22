defmodule Bonfire.UI.Social.SaveFeedPresetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, default: "save_feed_preset"
  prop event_target, :any, required: true
end
