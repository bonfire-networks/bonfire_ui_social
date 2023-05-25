
defmodule Bonfire.Social.Block.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  # import Bonfire.UI.Common

def handle_event("unblock", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :ghost, current_user: current_user(socket)),
   {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :silence, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted?: false, silenced?: false, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unblocked this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def handle_event("block", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :ghost, current_user: current_user(socket)),
   {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :silence, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted?: true, silenced?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully blocked this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def handle_event("block_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :ghost, :instance_wide),
   {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :silence, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted_instance_wide?: true, silenced_instance_wide?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully blocked instance-wide this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not block"))}
  end
end

def handle_event("unblock_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :ghost, :instance_wide),
  {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :silence, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()

    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted_instance_wide?: false, silenced_instance_wide?: false,  skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unblocked instance-wide this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def handle_event("unghost", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :ghost, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted?: false, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unghosted this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unghost"))}
  end
end

def handle_event("ghost", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :ghost, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully ghosted this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unghost"))}
  end
end


def handle_event("ghost_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :ghost, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted_instance_wide?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully ghosted instance-wide this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not ghost"))}
  end
end

def handle_event("unghost_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :ghost, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()

    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [ghosted_instance_wide?: false, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unghosted instance-wide this user"))}
  else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unghost"))}
  end
end


def handle_event("unsilence", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :silence, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [silenced?: false, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unsilenced this user"))}
    else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def handle_event("silence", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :silence, current_user: current_user(socket)) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [silenced?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully silenced this user"))}
    else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end



def handle_event("silence_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.block(id, :silence, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [silenced_instance_wide?: true, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully silenced instance-wide this user"))}
    else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def handle_event("unsilence_instance_wide", %{"id" => id} = _params, socket) do
  with {:ok, _} <- Bonfire.Boundaries.Blocks.unblock(id, :silence, :instance_wide) do
    Bonfire.UI.Common.OpenModalLive.close()
    ComponentID.send_assigns(
      Bonfire.UI.Common.BlockButtonProfileLive,
      id,
      [silenced_instance_wide?: false, skip_preload: true],
      socket
    )
    {:noreply, assign_flash(socket, :info, l("You have successfully unsilenced instance-wide this user"))}
    else
    # This block will be executed if either of the unblock operations fails
    # You can handle errors here
    error ->
      IO.inspect(error, label: "Error")
      {:noreply, assign_flash(socket, :error, l("Could not unblock"))}
  end
end

def preload(list_of_assigns, opts \\ []) do
  preload_assigns_async(list_of_assigns, &assigns_to_params/1, &do_preload/3, opts)
end

defp assigns_to_params(assigns) do
  object = e(assigns, :object, nil)
  %{
    component_id: assigns.id,
    object: object,
    object_id: e(assigns, :object_id, nil) || ulid(object),
  }
end

defp do_preload(list_of_components, list_of_ids, current_user) do
  # Here we're checking if the user is ghosted / silenced by user or instance
  ghosted? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :ghost, current_user: current_user)
  ghosted_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :ghost, :instance_wide)
  silenced? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :silence, current_user: current_user)
  silenced_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(List.first(list_of_ids), :silence, :instance_wide)

  list_of_components
  |> Map.new(fn component ->
    {component.component_id,
     %{
        ghosted?: ghosted?,
        ghosted_instance_wide?: ghosted_instance_wide?,
        silenced?: silenced?,
        silenced_instance_wide?: silenced_instance_wide?
     }}
  end)
end

end
