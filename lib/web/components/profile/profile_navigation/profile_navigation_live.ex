defmodule Bonfire.UI.Social.ProfileNavigationLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop user, :map
end
