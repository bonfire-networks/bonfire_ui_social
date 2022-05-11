defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

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
  prop object_boundary, :any, default: nil

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end
end
