defmodule Bonfire.UI.Social.Activity.JoinRequestActionsLive do
  @moduledoc "Moderator decisions on join requests, retaining feedback while a notification stays in the stream."
  use Bonfire.UI.Common.Web, :stateful_component

  prop request_id, :string, required: true
  data request_status, :atom, default: nil
  data request_error, :string, default: nil

  @doc false
  def update_many(assigns_sockets) do
    [{first_assigns, first_socket} | _] = assigns_sockets
    reviewer = current_user(first_assigns) || current_user(first_socket)

    # only rows not loaded yet: re-rendering the activity must neither re-query nor overwrite a decision just made (an approved request no longer exists)
    requests =
      for({assigns, socket} <- assigns_sockets, is_nil(socket.assigns.request_status), do: assigns.request_id)
      |> Bonfire.Social.Requests.list_by_ids(current_user: reviewer)
      |> Map.new(fn request -> {request.id, request} end)

    Enum.map(assigns_sockets, fn {assigns, socket} ->
      status =
        socket.assigns.request_status ||
          Bonfire.Social.Requests.review_status(Map.get(requests, assigns.request_id)) ||
          :unavailable

      socket
      |> assign(assigns)
      |> assign(:request_status, status)
    end)
  end
end
