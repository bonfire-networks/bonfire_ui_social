defmodule Bonfire.UI.Social.EditPostLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any, default: nil

  prop parent_id, :string, default: nil
  prop activity_component_id, :string, default: nil

  def render(assigns) do
    assigns
    |> assign(post_content: Bonfire.UI.Social.Activity.NoteLive.post_content(assigns[:object]))
    |> render_sface()
  end
end
