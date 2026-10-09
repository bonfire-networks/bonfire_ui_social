defmodule Bonfire.UI.Social.SaveFeedPresetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, default: "save_feed_preset"
  prop event_target, :any, required: true

  @doc "Show the bookmark icon before the \"Save as custom feed\" label."
  prop show_icon, :boolean, default: true

  prop summary_class, :css_class,
    default:
      "min-h-11 flex cursor-pointer items-center gap-2 rounded-box text-sm text-primary focus-visible:outline focus-visible:outline-2"
end
