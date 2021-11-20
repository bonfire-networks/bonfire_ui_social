defmodule  Bonfire.UI.Social.FeedViewLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop feed, :any
  prop feed_id, :string, required: true
  prop page_info, :any
  prop showing_within, :any, default: nil
end
