defmodule Bonfire.UI.Social.SidebarLive do
  use Surface.Component
  alias Surface.Components.LivePatch

  prop name, :string, required: true
  prop user_image, :string, required: true
  prop username, :string, required: true
end
