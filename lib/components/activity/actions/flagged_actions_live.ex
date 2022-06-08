defmodule Bonfire.UI.Social.FlaggedActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop activity, :map
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop permalink, :string
  prop showing_within, :any
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop object_type_readable, :any
  prop flagged, :any

end
