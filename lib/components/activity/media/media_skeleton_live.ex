defmodule Bonfire.UI.Social.Activity.MediaSkeletonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop multimedia_count, :any, default: 0
  prop image_count, :any, default: 0
  prop video_count, :any, default: 0
  prop gif_count, :any, default: 0
  prop visual_count, :any, default: 0
  prop link_count, :any, default: 0
  prop visible_link_count, :any, default: 0
  prop link_preview_count, :any, default: 0
  prop no_cover_links?, :boolean, default: false
  prop small_icon_links?, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
end
