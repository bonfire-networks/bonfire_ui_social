defmodule Bonfire.UI.Social.Activity.PermittedActionsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop creator, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop parent_id, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop verb, :string, default: nil
  prop permalink, :string, default: nil
  prop published_in, :any, default: nil
  prop participants, :any, default: nil

  @doc "The object's boundary for the viewer, when the feed has loaded it (`Bonfire.Boundaries.LiveHandler.preload_boundaries/2`): the menu is then decided from it, with no query on opening"
  prop object_boundary, :any, default: nil

  # from `MoreActionsLive`, so deleting a remote object doesn't promise a request to other instances
  prop is_remote, :boolean, default: nil

  data boundary, :any, default: nil

  @doc "What the viewer may do here, by action; `nil` until the menu is first opened, unless decided from a loaded `object_boundary`."
  data permitted, :map, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if is_nil(e(assigns(socket), :permitted, nil)) and
         loaded?(e(assigns(socket), :object_boundary, nil)),
       do: {:ok, assign_permitted(socket)},
       else: {:ok, socket}
  end

  # opening the menu, where the feed didn't load the boundary
  def handle_event("load", _params, %{assigns: %{permitted: nil}} = socket),
    do: {:noreply, assign_permitted(socket)}

  def handle_event("load", _params, socket), do: {:noreply, socket}

  defp loaded?(%{object_id: _, verbs: verbs}) when is_list(verbs), do: true
  defp loaded?(_), do: false

  defp assign_permitted(socket) do
    %{object: object, published_in: published_in, __context__: context} =
      assigns(socket)

    current_user = current_user(socket)
    loaded = e(assigns(socket), :object_boundary, nil)

    boundary =
      if loaded?(loaded), do: loaded, else: fetch_boundary(id(object), current_user)

    assign(socket,
      boundary: boundary,
      permitted: %{
        edit: Bonfire.Boundaries.can?(context, :edit, boundary) == true,
        describe: Bonfire.Boundaries.can?(context, :describe, boundary) == true,
        # lock or unlock, as `Blocks.lock/2` and `Blocks.unlock/2` both allow: whoever may change its boundary or moderate the group it is in, or an instance admin
        lock:
          Bonfire.Boundaries.can?(context, {:any, [:grant, :mediate]}, boundary) == true or
            Bonfire.Boundaries.can?(context, :grant, :instance) == true,
        download: Bonfire.Social.maybe_can?(context, :edit, object, boundary) == true,
        delete:
          not is_nil(id(object)) and
            Bonfire.UI.Social.Activity.DeleteObjectLive.can_delete?(context, object, boundary) ==
              true,
        remove_from_group: can_remove_from_group?(current_user, published_in, object, boundary)
      }
    )
  end

  # the call the feeds' batch preload makes, for one id: `Boundaries.boundary_on_object/2` returns a different shape (a `%Controlled{}`, not the preferred preset `%Acl{}`)
  defp fetch_boundary(nil, _current_user), do: nil

  defp fetch_boundary(object_id, current_user),
    do:
      Bonfire.Boundaries.boundaries_on_objects([object_id], current_user)
      |> Map.get(object_id)

  defp can_remove_from_group?(current_user, published_in, object, boundary)

  defp can_remove_from_group?(_current_user, nil, _object, _boundary), do: false

  # with the post's boundary loaded, as `Categories.can_remove_post_from_group?/3` decides it: its author, or one who may moderate it, which a group's moderators may do to what is published in it (its moderators ACL) as they may the group, mirrors included. Not instance-wide moderation, which that doesn't count either
  defp can_remove_from_group?(
         current_user,
         _published_in,
         object,
         %{object_id: _, verbs: verbs} = boundary
       )
       when is_list(verbs) do
    user_id = id(current_user)

    (not is_nil(user_id) and
       (e(object, :created, :creator_id, nil) || e(object, :created, :creator, :id, nil) ||
          e(object, :creator_id, nil)) == user_id) or
      Bonfire.Boundaries.can?(current_user, :mediate, boundary) == true
  end

  defp can_remove_from_group?(current_user, published_in, object, _boundary) do
    not is_nil(published_in) and not is_nil(id(object)) and
      maybe_apply(
        Bonfire.Classify.Categories,
        :can_remove_post_from_group?,
        [current_user, published_in, object],
        fallback_return: false
      ) == true
  end
end
