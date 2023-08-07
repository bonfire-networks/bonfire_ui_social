defmodule Bonfire.UI.Social.PostLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Untangle

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Post"),
       thread_title: nil,
       page: "discussion",
       #  to_circles: [],
       participants: nil,
       #  smart_input_opts: %{prompt: l("Reply")},
       activity: nil,
       back: true,
       showing_within: :thread,
       object: nil,
       #  sidebar_widgets: [
       #    users: [
       #      secondary: [
       #       {Bonfire.Tag.Web.WidgetTagsLive, []}
       #      ]
       #    ],
       #    guests: [
       #      secondary: nil
       #    ]
       #  ],
       #  without_sidebar: true,
       post_id: nil,
       thread_id: nil,
       #  reply_to_id: nil,
       thread_mode: maybe_to_atom(e(params, "mode", nil)),
       search_placeholder: nil,
       #  to_boundaries: nil,
       loading: false
     )}
  end

  def do_handle_params(%{"id" => id} = params, _url, socket) do
    socket =
      socket
      |> assign(
        params: params,
        post_id: id,
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

  def do_handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> redirect_to(path(:write))}
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
