defmodule Bonfire.UI.Social.Activity.RepliedDateAgoLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.UI.Social.BoundaryIconLive

  prop object, :any
  prop verb_display, :string
  prop date_ago, :any
  prop permalink, :string
  prop object_type, :any

end
