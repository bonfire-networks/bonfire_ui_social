defmodule Bonfire.UI.Social.Activity.ProcessReflowLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch

  alias Bonfire.Social.{Likes}

  prop object, :any, required: true
  prop showing_within, :any



end
