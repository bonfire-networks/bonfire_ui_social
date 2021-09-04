defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.Common.Web.ComponentID
  alias Bonfire.UI.Social.Activity.BoostActionLive

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop activity, :map
  prop object, :map
  prop permalink, :string
  prop showing_within_thread, :boolean
  prop hide_reply, :boolean
  prop reply_click, :string

end
