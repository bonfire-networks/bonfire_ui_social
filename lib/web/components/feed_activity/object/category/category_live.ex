defmodule Bonfire.UI.Social.Activity.CategoryLive do
  use Bonfire.Web, :stateless_component



  def name(object) do
    name = e(object, :name, e(object, :profile, :name, e(object, :post_content, :name, e(object, :title, "Unidentified category"))))
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
