defmodule Bonfire.UI.Social.SidebarNavigationLive do
  use Surface.Component
  alias Surface.Components.LivePatch

  prop page, :string, required: true
  prop username, :string, required: true
end
