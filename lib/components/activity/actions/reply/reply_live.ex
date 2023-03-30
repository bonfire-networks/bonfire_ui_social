defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string, required: true
  prop object_type, :any
  prop activity_id, :string
  prop permalink, :string
  prop replied, :any
  prop boost_count, :any
  prop showing_within, :atom, default: nil
  prop hide_reply, :any
  prop object_boundary, :any, default: nil

  prop class, :css_class,
    default: "flex btn btn-ghost btn-square rounded btn-sm text-base-content/70"

  prop reply_btn_text, :string, default: nil
  prop cannot_reply_text, :string, default: nil

  slot default
  slot cannot_reply

  def count(replied) do
    # debug(replied)
    e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0)
  end
end
