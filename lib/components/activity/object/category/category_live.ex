defmodule Bonfire.UI.Social.Activity.CategoryLive do
  use Bonfire.UI.Common.Web, :stateless_component

  def preloads(), do: [
    :character,
    :profile
  ]

  def name(object) do
    e(object |> debug, :name, e(object, :profile, :name, e(object, :post_content, :name, e(object, :title, "Unidentified category"))))
  end

  defp crumbs(%{name: name, parent: grandparent} = _parent) do # TODO: preload?
    crumbs(grandparent) <> crumb_link(name)
  end
  defp crumbs(%{name: name}) do
    crumb_link(name)
  end
  defp crumbs(_) do
    ""
  end

  def crumb_link(name) do
    "<a data-phx-link='redirect' data-phx-link-state='push' href='/+#{name}'>#{name}</a> > "
  end


end
