defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string
  prop permalink, :string
  prop reply_smart_input_text, :string
  prop reply_to_text, :any
  prop replied, :any
  prop boost_count, :any
  prop showing_within, :any
  prop hide_reply, :any

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end
end
