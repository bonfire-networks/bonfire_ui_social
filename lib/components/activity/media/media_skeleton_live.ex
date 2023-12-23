defmodule Bonfire.UI.Social.Activity.MediaSkeletonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop multimedia_count, :any, default: nil
  prop image_count, :any, default: nil
  prop link_count, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :boolean, default: false
end
