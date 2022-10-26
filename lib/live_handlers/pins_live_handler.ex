defmodule Bonfire.Social.Pins.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  # pin in LV stateful
  def handle_event(
        "pin",
        %{"direction" => "up"} = params,
        %{assigns: %{object: object}} = socket
      ) do
    do_pin(object, params, socket)
  end

  # pin in LV
  def handle_event("pin", %{"direction" => "up", "id" => id} = params, socket) do
    do_pin(id, params, socket)
  end

  # unpin in LV
  def handle_event("pin", %{"direction" => "down", "id" => id} = params, socket) do
    with _ <-
           Bonfire.Social.Pins.unpin(
             current_user_required!(socket),
             id,
             maybe_to_atom(e(params, "scope", nil))
           ) do
      pin_action(id, false, params, socket)
    end
  end

  def do_pin(object, params, socket) do
    scope =
      maybe_to_atom(e(params, "scope", nil))
      |> debug()

    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("pin"), object),
         {:ok, _pin} <-
           Bonfire.Social.Pins.pin(current_user, object, scope) do
      pin_action(object, true, params, socket)
    else
      {:error,
       %Ecto.Changeset{
         errors: [
           pinner_id: {"has already been taken", _}
         ]
       }} ->
        debug("previously pinned, but UI didn't know")
        pin_action(object, true, params, socket)

      {:error, e} ->
        error(e)

      other ->
        debug(other)
        other
    end
  end

  defp pin_action(object, pinned?, params, socket) do
    ComponentID.send_updates(
      e(params, "component", Bonfire.UI.Common.PinActionLive),
      ulid(object),
      my_pin: pinned?
    )

    {:noreply,
     socket
     |> assign_flash(:info, if(pinned?, do: l("Pinned!"), else: l("Unpinned")))}
  end

  # defp list_my_pinned(current_user, objects) when is_list(objects) do
  #   Cache.cached_preloads_for_objects("my_pin:#{ulid(current_user)}:", objects, fn list_of_ids -> do_list_my_pinned(current_user, list_of_ids) end)
  # end

  # defp do_list_my_pinned(current_user, list_of_ids)
  #      when is_list(list_of_ids) and length(list_of_ids) > 0 do
  #   Bonfire.Social.Pins.get!(current_user, list_of_ids, preload: false)
  #   |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end)
  # end

  # defp do_list_my_pinned(_, _objects), do: %{}
end
