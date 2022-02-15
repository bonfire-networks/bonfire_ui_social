defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :any
  prop object, :any
  prop flagged, :any
end
