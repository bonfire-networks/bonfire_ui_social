defmodule Bonfire.UI.Social.SidebarNavigationLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch

  prop page, :string, required: true
  # prop username, :string, required: true
end
