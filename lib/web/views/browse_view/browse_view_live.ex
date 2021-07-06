defmodule  Bonfire.UI.Social.BrowseViewLive do
  use Bonfire.Web, :stateless_component

  prop feed, :list, required: false
  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "feed"
  prop smart_input, :boolean, required: true
  prop has_private_tab, :boolean, required: true
  prop smart_input_placeholder, :string
  prop smart_input_text, :string
  prop search_placholder, :string


end
