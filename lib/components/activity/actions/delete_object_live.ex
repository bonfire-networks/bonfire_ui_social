defmodule Bonfire.UI.Social.Activity.DeleteObjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive

  prop creator_id, :string, default: nil
  prop object, :any
  prop parent_id, :string, default: nil
  prop object_boundary, :any, default: nil
  prop object_type, :any
  prop object_type_readable, :any
  prop action, :string, default: nil
  prop explanation, :string, default: nil

  prop skip_permission_check, :boolean, default: false

  prop hide_icon, :boolean, default: false
  prop icon_class, :css_class, default: nil
  prop hide_text, :boolean, default: false
  prop with_password_prompt, :boolean, default: false

  prop form_opts, :map, default: %{}

  prop open_btn_class, :css_class, default: "flex items-center gap-2 text-sm text-base-content"

  prop redirect_after, :any, default: nil

  def can_delete?(context, object, object_boundary \\ nil) do
    current_user_id(context) ==
      (e(object, :created, :creator_id, nil) ||
         e(object, :created, :creator, :id, nil) ||
         e(object, :creator, :id, nil) ||
         e(object, :creator_id, nil)) or
      (Types.object_type(object) != Bonfire.Data.Identity.User and
         (Bonfire.Boundaries.can?(context, :delete, object_boundary) ||
            Bonfire.Boundaries.can?(context, :delete, :instance)))
  end
end
