defmodule Bonfire.UI.Social.Activity.RepliedDateAgoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.BoundaryIconLive

  prop object, :any
  prop verb_display, :string
  prop date_ago, :any
  prop permalink, :string
  prop object_type, :any
  prop object_boundary, :any, default: nil

end
