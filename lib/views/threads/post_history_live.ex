defmodule Bonfire.UI.Social.PostHistoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    # is_guest? = is_nil(current_user_id(socket.assigns))

    {:ok,
     socket
     |> assign(
       page_title: l("Post history"),
       page: "history",
       activity: nil,
       post: nil,
       object: nil,
       object_id: nil,
       post_id: nil,
       back: true,
       nav_items: Bonfire.Common.ExtensionModule.default_nav()
     )}
  end

  def handle_params(%{"id" => id} = params, _url, socket) when is_binary(id) do
    debug(id, "object_id")

    socket =
      socket
      |> assign(
        # params: params,
        object_id: id
        # thread_id: id
      )

    with %Phoenix.LiveView.Socket{} = socket <-
           Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket) do
      {:noreply, socket}
    else
      {:error, e} ->
        {:noreply, assign_error(socket, e)}

      other ->
        error(other)
        {:noreply, socket}
    end
  end
end
