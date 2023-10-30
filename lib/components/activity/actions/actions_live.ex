defmodule Bonfire.UI.Social.Activity.ActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop activity, :any, default: nil
  prop object, :any, required: true
  # prop profile, :any, default: nil
  prop thread_id, :string, required: true
  prop object_type, :any, required: true
  prop object_type_readable, :any, required: true
  prop verb, :string, required: true
  prop reply_count, :any, default: nil
  prop permalink, :string, required: true
  prop activity_component_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop showing_within, :atom, default: nil
  prop hide_reply, :boolean, default: false
  prop viewing_main_object, :boolean, default: false
  prop flagged, :any, default: nil
  prop thread_mode, :any, default: nil
  prop object_boundary, :any, default: nil

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end

  def the_activity(activity, object) do
    activity || e(object, :activity, nil) || object
  end
end
