defmodule Bonfire.UI.Social.Actions.ReplyButtonLive do
  use Bonfire.Web, :stateless_component

  prop reply_click, :any
  prop hide_reply, :any
  prop permalink, :string, required: true
  prop nested_replies_count, :integer, default: 0
  prop direct_replies_count, :integer, default: 0
end
