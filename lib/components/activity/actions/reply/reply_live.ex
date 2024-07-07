defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_id, :string, default: nil
  prop object_type, :any
  prop permalink, :string
  prop reply_count, :any, default: nil
  prop showing_within, :atom, default: nil
  prop hide_reply, :any
  prop object_boundary, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop event_target, :any, default: nil

  prop class, :css_class,
    default: "flex btn btn-ghost group btn-circle btn-sm hover:bg-primary/10"

  # prop reply_btn_text, :string, default: nil
  prop cannot_reply_text, :string, default: nil

  slot default
  slot cannot_reply
end
