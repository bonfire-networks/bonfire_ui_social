defmodule  Bonfire.UI.Social.BrowseViewLive do
  use Bonfire.Web, :stateless_component

  prop feed, :list, required: false
  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "timeline"
  prop smart_input, :boolean, required: true
  prop has_private_tab, :boolean, required: true
  prop smart_input_placeholder, :string
  prop smart_input_text, :string
  prop search_placholder, :string


  def update(%{feed: feed} =assigns, socket) when is_list(feed) and length(feed)>0 do
    IO.inspect("BrowseViewLive: a feed was provided")

    {:ok, assign(socket, assigns) }
  end


  def update(assigns, socket) do

    if module_enabled?(Bonfire.Social.Feeds.BrowseLive), do: Bonfire.Social.Feeds.BrowseLive.default_feed(socket),
    else: {:ok, assign(socket, assigns) }

  end
end
