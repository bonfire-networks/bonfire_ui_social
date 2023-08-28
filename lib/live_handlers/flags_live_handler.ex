defmodule Bonfire.Social.Flags.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  # flag in LV
  def handle_event("flag", %{"id" => id} = params, socket) do
    # debug(socket)
    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("flag"), id),
         {:ok, _flag} <- Bonfire.Social.Flags.flag(current_user, id) do
      Bonfire.UI.Common.OpenModalLive.close()

      {
        :noreply,
        socket
        |> assign_flash(:info, l("%{user_or_thing} flagged!", user_or_thing: params["type"]))
        |> assign(flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, true}])
      }
    end
  end

  # unflag in LV
  def handle_event("unflag", %{"id" => id} = attrs, socket) do
    current_user = current_user_required!(socket)

    subject =
      if attrs["subject"] &&
           Bonfire.Boundaries.can?(socket.assigns[:__context__], :mediate, attrs["context"]),
         do:
           Bonfire.Me.Users.by_id(attrs["subject"], current_user: current_user) |> ok_unwrap(nil),
         else: current_user

    with _ <- Bonfire.Social.Flags.unflag(subject, id) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Unflagged!"))
       #  |> assign(flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, false}])
       |> Bonfire.UI.Social.ActivityLive.remove()}
    end
  end

  def handle_event("unpublish", %{"id" => id, "context" => context} = attrs, socket) do
    current_user = current_user_required!(socket)

    subject =
      if attrs["subject"] &&
           Bonfire.Boundaries.can?(socket.assigns[:__context__], :mediate, context),
         do:
           Bonfire.Me.Users.by_id(attrs["subject"], current_user: current_user) |> ok_unwrap(nil),
         else: current_user

    with {:ok, _} <- Bonfire.Social.Boosts.unboost(context, id),
         _ <- Bonfire.Social.Flags.unflag(subject, id) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Unpublished!"))
       #  |> assign(flagged: Map.get(socket.assigns, :flagged, []) ++ [{id, false}])
       |> Bonfire.UI.Social.ActivityLive.remove()}
    end
  end
end
