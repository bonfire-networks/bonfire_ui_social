defmodule Bonfire.UI.Social.Activity.MainObjectInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :map
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop permalink, :string
  prop object_type_readable, :any
  prop showing_within, :atom, default: nil
  prop hide_reply, :boolean
  prop viewing_main_object, :boolean
  prop flagged, :any
  prop participants, :list
  prop object_boundary, :any, default: nil
end
