defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string, required: true
  prop activity_id, :string
  prop permalink, :string
  prop reply_to_text, :any
  prop replied, :any
  prop boost_count, :any
  prop showing_within, :any
  prop hide_reply, :any
  prop object_boundary, :any, default: nil

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end


end