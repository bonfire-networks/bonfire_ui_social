defmodule Bonfire.UI.Social.Activity.MediaSkeletonLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop multimedia_count, :any, default: nil
  prop image_count, :any, default: nil
  prop link_count, :any, default: nil
end
