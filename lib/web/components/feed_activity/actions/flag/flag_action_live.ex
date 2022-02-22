defmodule Bonfire.UI.Social.FlagActionLive do
  use Bonfire.Web, :stateless_component
  alias Phoenix.LiveView.JS

  prop object, :any
  prop label, :string
  prop my_flag, :any
  prop class, :string

end
