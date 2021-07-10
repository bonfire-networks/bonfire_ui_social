defmodule Bonfire.UI.Social.Activity.ReplyLive do
  use Bonfire.Web, :stateless_component

  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  prop permalink, :string
  prop replied, :any
  prop boost_count, :any
  prop showing_within_thread, :boolean
  prop hide_reply, :any
  prop reply_click, :any
end
