defmodule  Bonfire.UI.Social.FeedViewLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true
  prop smart_input_placeholder, :string
  prop smart_input_text, :string
  prop search_placholder, :string
  prop feed_title, :string
  prop user, :map
  prop following, :map

end
