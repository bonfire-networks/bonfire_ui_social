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

  # whether the object came from elsewhere, so no deletion request goes out for it; when not given, read off its `peered`
  prop is_remote, :boolean, default: nil

  # whether whoever deletes it may also take it out of its group, which reaches the group's followers elsewhere where deleting a remote object doesn't
  prop removable_from_group, :boolean, default: false

  prop label, :string, default: nil

  prop skip_permission_check, :boolean, default: false

  prop hide_icon, :boolean, default: false
  prop icon_class, :css_class, default: nil
  prop hide_text, :boolean, default: false

  prop form_opts, :map, default: %{}

  prop open_btn_class, :css_class, default: "flex items-center gap-2 text-sm text-base-content"

  prop redirect_after, :any, default: nil

  # as `MoreActionsLive` tells it, without a query: a remote object carries its `peered` canonical URI
  def remote?(is_remote, _object) when is_boolean(is_remote), do: is_remote
  def remote?(_, object), do: not is_nil(e(object, :peered, :canonical_uri, nil))

  def can_delete?(context, object, object_boundary \\ nil) do
    Types.object_type(object) != Bonfire.Data.Identity.User and
      (object_boundary == :skip_boundary_preload or
         Bonfire.Social.maybe_can?(
           context,
           :delete,
           object,
           object_boundary
         ))
  end
end
