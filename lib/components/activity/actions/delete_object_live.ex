defmodule Bonfire.UI.Social.Activity.DeleteObjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive

  prop creator_id, :string, default: nil
  prop object, :any
  prop object_boundary, :any, default: nil
  prop object_type, :any
  prop object_type_readable, :any
  prop action, :string, default: "Bonfire.Social.Objects:delete"
  prop explanation, :string, default: nil

  prop hide_icon, :boolean, default: false
  prop hide_text, :boolean, default: false

  prop open_btn_class, :css_class,
    default: "flex items-center gap-2 text-base md:text-sm text-neutral-content/80"

  prop redirect_after, :any, default: nil
end
