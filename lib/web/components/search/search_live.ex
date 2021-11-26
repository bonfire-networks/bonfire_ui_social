defmodule Bonfire.UI.Social.SearchLive do
  use Bonfire.Web, :stateless_component

  def render(assigns) do
    if module_enabled?(Bonfire.Search.Web.FormLive) do
      ~F"""
      <Bonfire.Search.Web.FormLive 
        search_limit=5
        show_more_link={true}
      />
      """
    else
      ~F"""
      """
    end
  end
end