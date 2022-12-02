defmodule Bonfire.UI.Social.DiscussionLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.LoadCurrentUserCircles,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Discussion"),
       page: "discussion",
       showing_within: :thread,
       # search_placeholder: l("Search this discussion"),
       to_circles: [],
       participants: nil,
       smart_input_opts: [prompt: l("Reply to this discussion")],
       without_sidebar: true,
       activity: nil,
       post: nil,
       object: nil,
       object_id: nil,
       post_id: nil,
       thread_id: nil,
       reply_to_id: nil,
       thread_mode: nil,
       url: nil,
       search_placeholder: nil,
       to_boundaries: nil,
       loading: false
     )}
  end

  def do_handle_params(%{"id" => id} = params, url, socket) when is_binary(id) do
    {:noreply,
     socket
     |> assign(
       object_id: id,
       url: url,
       reply_to_id: e(params, "reply_to_id", id)
     )
     |> Bonfire.Social.Objects.LiveHandler.load_object_assigns()}
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
