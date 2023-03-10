defmodule Bonfire.UI.Social.Activity.LinkToActivityLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop thread_id, :string, default: nil
  prop object_type, :any, required: true
  prop permalink, :string, required: true

  # prop showing_within, :atom, default: nil
  # prop viewing_main_object, :boolean, default: false
  # prop object_boundary, :any, default: nil

  slot default
end
