defmodule Bonfire.UI.Social.Activity.JoinRequestActionsLive do
  @moduledoc "Moderator decisions on join requests, retaining feedback while a notification stays in the stream."
  use Bonfire.UI.Common.Web, :stateful_component

  prop request_id, :string, required: true

  @doc "The group asked to join, to tell whether it is hosted here, where its moderators approve, or on another instance, which does."
  prop group, :any, default: nil
  data request_status, :atom, default: nil
  data request_error, :string, default: nil
  data remote_group?, :boolean, default: false

  @doc false
  def update_many(assigns_sockets) do
    [{first_assigns, first_socket} | _] = assigns_sockets
    reviewer = current_user(first_assigns) || current_user(first_socket)

    # only rows not loaded yet: re-rendering the activity must neither re-query nor overwrite a decision just made (an approved request no longer exists)
    requests =
      for(
        {assigns, socket} <- assigns_sockets,
        is_nil(socket.assigns.request_status),
        do: assigns.request_id
      )
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
      |> assign(
        :remote_group?,
        not is_nil(assigns[:group]) and not Bonfire.Social.is_local?(assigns[:group])
      )
    end)
  end
end
