defmodule Bonfire.UI.Social.Activity.GroupLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop object_boundary, :any, default: nil

  def preloads(),
    do: [
      :character,
      :profile,
      parent_category: [:profile, :character]
    ]

  def name(object) do
    e(
      object,
      :name,
      e(
        object,
        :profile,
        :name,
        e(object, :post_content, :name, e(object, :title, "Unidentified category"))
      )
    )
  end

  # TODO: preload?
  # defp crumbs(%{name: name, parent: grandparent} = _parent) do
  #   crumbs(grandparent) <> crumb_link(name)
  # end

  # defp crumbs(%{name: name}) do
  #   crumb_link(name)
  # end

  # defp crumbs(_) do
  #   ""
  # end

  def crumb_link(name) do
    "<a data-phx-link='redirect' data-phx-link-state='push' href='/+#{name}'>#{name}</a> > "
  end
end
