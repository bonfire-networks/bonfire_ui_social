defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.UI.Social.Activity.BoostActionLive

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop activity, :map
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop permalink, :string
  prop object_type_readable, :any
  prop reply_smart_input_text, :string
  prop showing_within, :any
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop flagged, :any
end
