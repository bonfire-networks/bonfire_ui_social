defmodule Bonfire.UI.Social.TabFilterButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_filters, :map, required: true
  prop event_target, :any, required: true
  prop get_button_class, :fun, required: true
  prop get_tab_toggle_value, :fun, required: true

  def should_hide_button?(button_type, button_field, assigns) do
    # Use preset exclusions directly from feed_filters
    exclusions = case button_field do
      :activity_types -> e(assigns, :feed_filters, :preset_excludes_activity_types, [])
      :object_types -> e(assigns, :feed_filters, :preset_excludes_object_types, [])
      :media_types -> e(assigns, :feed_filters, :preset_excludes_media_types, [])
      _ -> []
    end
    
    button_type in exclusions
  end
end
