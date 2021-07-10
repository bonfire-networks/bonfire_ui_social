defmodule Bonfire.UI.Social.Activity.ProcessReflowLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch
  import Bonfire.UI.Social.Integration
  alias Bonfire.Social.{Likes}

  prop object, :map, required: true
  prop within_feed, :boolean, required: false, default: false


  def update(assigns, socket), do: Bonfire.UI.Social.Activity.ProcessListLive.update(assigns, socket)

end
