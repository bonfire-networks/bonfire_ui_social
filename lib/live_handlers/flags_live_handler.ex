defmodule Bonfire.Social.Flags.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  # flag in LV
  def handle_event("flag", %{"id" => id}, socket) do
    # debug(socket)
    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("flag"), id),
         {:ok, _flag} <- Bonfire.Social.Flags.flag(current_user, id) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, "Flagged!")
       |> assign(flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, true}])}
    end
  end

  # unflag in LV
  def handle_event("unflag", %{"id" => id} = attrs, socket) do
    current_user = current_user_required!(socket)

    subject =
      if attrs["subject"] && Bonfire.Me.Users.is_admin?(current_user),
        do: Bonfire.Me.Users.by_id(attrs["subject"], current_user: current_user) |> ok_unwrap(nil),
        else: current_user

    with _ <- Bonfire.Social.Flags.unflag(subject, id) do
      {:noreply,
       socket
       |> assign_flash(:info, "Unflagged!")
       |> assign(flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, false}])}
    end
  end
end
