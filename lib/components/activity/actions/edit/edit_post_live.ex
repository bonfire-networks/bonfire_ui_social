defmodule Bonfire.UI.Social.EditPostLive do
  use Bonfire.UI.Common.Web, :stateless_component

  slot default

  prop object, :any, default: nil
  prop object_boundary, :any, default: nil

  prop parent_id, :string, default: nil
  prop activity_component_id, :string, default: nil

  def render(assigns) do
    assigns
    |> assign(
      versioning_enabled: Bonfire.Social.PostContents.versioning_enabled?(assigns[:__context__]),
      read_only:
        !Bonfire.Boundaries.can?(assigns[:__context__], :edit, [
          assigns[:object_boundary]
          |> debug("object_boundary"),
          assigns[:object]
          |> debug("object")
        ])
    )
    |> render_sface()
  end
end
