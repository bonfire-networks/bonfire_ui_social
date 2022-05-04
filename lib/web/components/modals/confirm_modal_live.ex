defmodule Bonfire.UI.Social.ConfirmModalLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Phoenix.LiveView.JS
  prop title, :string
  prop object_id, :any
  slot content
  slot actions

end
