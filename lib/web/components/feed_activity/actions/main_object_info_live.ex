defmodule Bonfire.UI.Social.Activity.MainObjectInfoLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.UI.Social.Activity.BoostActionLive

  prop activity, :map
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop permalink, :string
  prop object_type_readable, :any
  prop showing_within, :any
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop flagged, :any
  prop participants, :list


end