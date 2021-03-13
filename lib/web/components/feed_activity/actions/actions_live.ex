defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.Web, :live_component

  defdelegate handle_event(action, attrs, socket), to: Bonfire.Web.LiveHandler

end
