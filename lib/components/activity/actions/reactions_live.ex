defmodule Bonfire.UI.Social.Activity.ReactionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, required: true
  prop permalink, :string, required: true

  prop showing_within, :atom, default: nil
  prop hide_reply, :boolean, default: false
  prop thread_mode, :any, default: nil
  prop object_boundary, :any, default: nil
  prop object_type_readable, :any, default: nil

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end
end
