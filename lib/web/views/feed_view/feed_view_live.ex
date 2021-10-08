defmodule  Bonfire.UI.Social.FeedViewLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop feed, :any
  prop page_info, :any
end
