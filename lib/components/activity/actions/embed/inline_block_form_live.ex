defmodule Bonfire.UI.Social.Activity.InlineBlockFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_id, :string, required: true
  prop object_label, :string, default: nil

  def render(assigns), do: render_sface(assigns)
end
