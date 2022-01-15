defmodule Bonfire.UI.Social.SidebarMobileLive do
  use Bonfire.Web, :stateless_component
  alias Surface.Components.LivePatch

  # prop name, :string, required: true
  # prop user_image, :string, required: true
  # prop username, :string, required: true
  prop page, :string, required: true
end
