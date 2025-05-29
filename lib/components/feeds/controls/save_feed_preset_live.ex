defmodule Bonfire.UI.Social.SaveFeedPresetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop event_target, :any, required: true
  prop open_btn_wrapper_class, :string, default: "w-full flex-1 mt-2"
end
