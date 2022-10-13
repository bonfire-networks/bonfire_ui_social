defmodule Bonfire.UI.Social.Activity.DeleteObjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive

  prop creator_id, :string, default: nil
  prop object, :any
  prop object_type, :any
  prop object_type_readable, :any
  prop action, :string, default: "Bonfire.Social.Objects:delete"
  prop explanation, :string, default: nil
  prop open_btn_class, :css_class, default: "flex items-center text-sm text-neutral"
  prop redirect_after, :any, default: nil
end
