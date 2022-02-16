defmodule Bonfire.UI.Social.Activity.FlaggedActionsLive do
  use Bonfire.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop activity, :map
  prop object, :map
  prop permalink, :string
  prop reply_smart_input_text, :string
  prop showing_within, :any
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop flagged, :any
end
