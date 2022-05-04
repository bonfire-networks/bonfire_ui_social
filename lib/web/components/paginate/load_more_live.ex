defmodule Bonfire.UI.Social.LoadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop live_handler, :string
  prop page_info, :map
  prop target, :any
  prop context, :any

end
