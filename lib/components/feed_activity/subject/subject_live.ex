defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Boundaries.Web.BoundaryIconLive

  prop activity, :map
  prop object, :any
  prop profile, :map
  prop character, :map
  prop date_ago, :any
  prop permalink, :string
  prop verb_display, :string
  prop showing_within, :any, default: :feed
  prop object_type, :any
  prop object_boundary, :any, default: nil

end
