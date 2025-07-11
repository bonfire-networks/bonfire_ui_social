defmodule Bonfire.UI.Social.SaveFeedPresetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop event_target, :any, required: true
  prop open_btn_wrapper_class, :string, default: "flex-1"
end
