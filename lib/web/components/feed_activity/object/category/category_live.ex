defmodule Bonfire.UI.Social.Activity.CategoryLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration


  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp crumbs(%{name: name, parent: grandparent} = _parent) do
    crumbs(grandparent) <> name<>" > "
  end
  defp crumbs(%{name: name}) do
    name<>" > "
  end
  defp crumbs(_) do
    ""
  end

end
