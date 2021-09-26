defmodule Bonfire.UI.Social.Activity.CategoryLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration


  def update(assigns, socket) do
    name = e(assigns, :object, :name, e(assigns, :object, :profile, :name, e(assigns, :object, :post_content, :name, e(assigns, :object, :title, "Unidentified category"))))
    {:ok, assigns_merge(socket, assigns, name: name)}
  end

  defp crumbs(%{name: name, parent: grandparent} = _parent) do
    crumbs(grandparent) <> crumb_link(name)
  end
  defp crumbs(%{name: name}) do
    crumb_link(name)
  end
  defp crumbs(_) do
    ""
  end

  def crumb_link(name) do
    "<a data-phx-link='redirect' data-phx-link-state='push' href='?s=#{name}'>#{name}</a> > "
  end

end
