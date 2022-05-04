defmodule Bonfire.UI.Social.SwitchUserViewLive.AccountUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.Me.Web.CreateUserLive

  prop current_account_users, :any
  prop go, :any
end
