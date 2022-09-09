defmodule Bonfire.UI.Social.SidebarNavigationLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :string, required: true


  declare_nav_component("Links to main activities feeds")

end
