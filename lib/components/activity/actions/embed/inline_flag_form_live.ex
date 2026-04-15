defmodule Bonfire.UI.Social.Activity.InlineFlagFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object_id, :string, required: true
  prop object_type, :string, default: nil
  prop object_label, :string, default: nil
  prop is_remote, :boolean, default: false

  def render(assigns), do: render_sface(assigns)
end
