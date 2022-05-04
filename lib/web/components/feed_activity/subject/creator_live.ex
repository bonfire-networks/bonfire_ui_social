defmodule Bonfire.UI.Social.Activity.CreatorLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.BoundaryIconLive

  prop profile, :any
  prop character, :any
  prop permalink, :string
  prop date_ago, :string
  prop created_verb_display, :string
  prop object_type, :any
end
