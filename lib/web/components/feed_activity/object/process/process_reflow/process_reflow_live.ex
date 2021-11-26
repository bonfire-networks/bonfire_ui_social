defmodule Bonfire.UI.Social.Activity.ProcessReflowLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration
  alias Bonfire.Social.{Likes}

  prop object, :map, required: true
  prop showing_within, :any



end
