defmodule Bonfire.UI.Social.ActivityBoundaryLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Social.Feeds.LiveHandler

  # Tip: use this component if you want to auto-preload boundaries (async), otherwise use `BoundaryIconStatelessLive` if a parent component can provide the `object_boundary` data

  prop object, :any, default: nil
  prop object_id, :any, default: nil

  # can also provide it manually
  prop object_boundary, :any, default: nil
  prop boundary_preset, :any, default: nil
  prop object_type, :any, default: nil

  prop scope, :any, default: nil
  prop parent_id, :any, default: nil

  prop with_icon, :boolean, default: false
  prop with_label, :boolean, default: false

  prop class, :css_class, default: nil
end
