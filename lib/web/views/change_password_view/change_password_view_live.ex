defmodule  Bonfire.UI.Social.ChangePasswordViewLive do
  use Bonfire.Web, :stateless_component

  prop form, :any
  prop error, :any, default: ""
  prop resetting_password, :boolean, default: false
end
