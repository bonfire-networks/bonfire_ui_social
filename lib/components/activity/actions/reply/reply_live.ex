defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_id, :string, default: nil
  prop object_type, :any, default: nil
  prop permalink, :string, default: nil
  prop reply_count, :any, default: nil
  prop showing_within, :atom, default: nil
  prop hide_reply, :any, default: nil
  prop object_boundary, :any, default: nil
  prop creator, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop event_target, :any, default: nil

  prop class, :css_class,
    default:
      "flex btn lg:tooltip lg:tooltip-top btn-ghost group btn-circle btn-sm hover:bg-primary/10 transition-transform duration-150 ease-out hover:scale-105 active:scale-95 hover:-translate-y-0.5"

  prop cannot_reply_text, :string, default: nil

  slot default
  slot cannot_reply
end
