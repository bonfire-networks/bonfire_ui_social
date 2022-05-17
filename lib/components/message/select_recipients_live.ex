defmodule Bonfire.UI.Social.SelectRecipientsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :list
  prop tab_id, :string
  prop to_circles, :list

end
