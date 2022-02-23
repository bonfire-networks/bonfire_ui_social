defmodule Bonfire.UI.Social.ConfirmModalLive do
  use Bonfire.Web, :stateless_component
  alias Phoenix.LiveView.JS
  prop title, :string
  prop object_id, :any
  slot content
  slot actions

end
