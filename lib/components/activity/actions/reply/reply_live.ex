defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop object_id, :string, required: true
  prop object_type, :any
  prop activity_id, :string
  prop permalink, :string
  prop reply_count, :any, default: nil
  prop showing_within, :atom, default: nil
  prop hide_reply, :any
  prop object_boundary, :any, default: nil
  prop activity_component_id, :string, default: nil

  prop class, :css_class,
    default: "flex btn btn-ghost btn-square rounded btn-sm text-base-content/70"

  prop reply_btn_text, :string, default: nil
  prop cannot_reply_text, :string, default: nil

  slot default
  slot cannot_reply
end
