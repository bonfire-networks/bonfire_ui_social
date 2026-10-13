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

  data boundary, :any, default: nil
  @doc "What the viewer may do here, by action; `nil` until the menu is first opened."
  data permitted, :map, default: nil

  def handle_event("load", _params, %{assigns: %{permitted: nil}} = socket),
    do: {:noreply, assign_permitted(socket)}

  def handle_event("load", _params, socket), do: {:noreply, socket}

  defp assign_permitted(socket) do
    %{object: object, creator: creator, published_in: published_in, __context__: context} =
      assigns(socket)

    current_user = current_user(socket)
    boundary = fetch_boundary(id(object), current_user)

    assign(socket,
      boundary: boundary,
      permitted: %{
        edit: Bonfire.Boundaries.can?(context, :edit, boundary) == true,
        describe: Bonfire.Boundaries.can?(context, :describe, boundary) == true,
        lock: Bonfire.Boundaries.can?(context, :grant, boundary) == true,
        unlock:
          (not is_nil(current_user) and id(creator) == id(current_user)) or
            Bonfire.Boundaries.can?(context, :grant, :instance) == true,
        download: Bonfire.Social.maybe_can?(context, :edit, object, boundary) == true,
        delete:
          not is_nil(id(object)) and
            Bonfire.UI.Social.Activity.DeleteObjectLive.can_delete?(context, object, boundary) ==
              true,
        remove_from_group: can_remove_from_group?(current_user, published_in, object)
      }
    )
  end

  # the call the feeds' batch preload makes, for one id: `Boundaries.boundary_on_object/2` returns a different shape (a `%Controlled{}`, not the preferred preset `%Acl{}`)
  defp fetch_boundary(nil, _current_user), do: nil

  defp fetch_boundary(object_id, current_user),
    do:
      Bonfire.Boundaries.boundaries_on_objects([object_id], current_user)
      |> Map.get(object_id)

  defp can_remove_from_group?(current_user, published_in, object) do
    not is_nil(published_in) and not is_nil(id(object)) and
      maybe_apply(
        Bonfire.Classify.Categories,
        :can_remove_post_from_group?,
        [current_user, published_in, object],
        fallback_return: false
      ) == true
  end
end
