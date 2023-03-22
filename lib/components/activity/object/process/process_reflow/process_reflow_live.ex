defmodule Bonfire.UI.Social.Activity.ProcessReflowLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Surface.Components.LivePatch

  # alias Bonfire.Social.Likes

  prop object, :any, required: true
  prop activity, :any, default: nil
  prop showing_within, :atom, default: nil
end
