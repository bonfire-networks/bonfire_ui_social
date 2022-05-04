defmodule Bonfire.UI.Social.ProfileFollowsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop selected_tab, :string
  prop feed, :list
  prop page_info, :any

end
