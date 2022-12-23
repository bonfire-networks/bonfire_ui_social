defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Boundaries.Web.BoundaryIconStatelessLive

  prop activity, :map, default: nil
  prop object, :any, default: nil
  prop profile, :map, default: nil
  prop character, :map, default: nil
  prop date_ago, :any, default: nil
  prop permalink, :string, default: nil
  prop verb_display, :string, default: nil
  prop showing_within, :any, default: :feed
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop activity_inception, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop thread_id, :string, default: nil
end
