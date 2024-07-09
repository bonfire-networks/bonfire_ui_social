defmodule Bonfire.UI.Social.Activity.PreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :map
  prop object, :map
  prop permalink, :string
  prop activity_component_id, :string
  prop date_ago, :string

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, socket}
  end
end
