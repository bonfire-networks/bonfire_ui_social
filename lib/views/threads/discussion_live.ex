defmodule Bonfire.UI.Social.DiscussionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Discussion"),
       page: "discussion",
       showing_within: :thread,
       # search_placeholder: l("Search this discussion"),
       #  to_circles: [],
       participants: nil,
       #  smart_input_opts: %{prompt: l("Reply to this discussion")},
       #  without_sidebar: true,
       activity: nil,
       post: nil,
       object: nil,
       object_id: nil,
       post_id: nil,
       #  thread_id: nil,
       back: true,
       #  reply_to_id: nil,
       thread_id: nil,
       thread_mode: maybe_to_atom(e(params, "mode", nil)),
       #  url: nil,
       search_placeholder: nil,
       #  to_boundaries: nil,
       loading: false
     )}
  end

  def do_handle_params(%{"id" => id} = params, _url, socket) when is_binary(id) do
    socket =
      socket
      |> assign(
        params: params,
        object_id: id,
        thread_id: id
        #  url: url
        #  reply_to_id: e(params, "reply_to_id", id)
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

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__,
        &do_handle_params/3
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
