defmodule Bonfire.UI.Social.FlaggedActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Common.OpenModalLive
  import Bonfire.UI.Social.Integration

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop activity, :map
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop permalink, :string
  prop showing_within, :atom, default: nil
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop object_type_readable, :any
  prop flagged, :any
  prop activity_component_id, :string, default: nil

  def flagged_subject(object) do
    e(object, :created, :creator, nil) || object
  end

  def flagged_character(object) do
    e(object, :created, :creator, :character, nil) || e(object, :character, nil)
  end

  def flagged_profile(object) do
    e(object, :created, :creator, :profile, nil) || e(object, :profile, nil)
  end
end
