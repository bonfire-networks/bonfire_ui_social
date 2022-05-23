defmodule Bonfire.UI.Social.Activity.DateAgoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Boundaries.Web.BoundaryIconLive

  prop object, :any
  prop verb_display, :string
  prop date_ago, :any
  prop viewing_main_object, :boolean
  prop permalink, :string
  prop showing_within, :string, default: :feed
  prop object_type, :any
  prop object_boundary, :any, default: nil

end
