defmodule Bonfire.UI.Social.PostLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  import Untangle

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
       page_title: l("Post"),
       page: "discussion",
       to_circles: [],
       participants: nil,
       smart_input_prompt: l("Reply to this thread"),
       activity: nil,
       showing_within: :thread,
       page_header_aside: [
         {Bonfire.UI.Social.ObjectHeaderAsideLive,
          [
            participants: [],
            thread_id: nil,
            activity: nil
          ]}
       ],
       object: nil,
       sidebar_widgets: [
         users: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ]
       ],
       #  without_sidebar: true,
       thread_id: nil,
       thread_mode: nil,
       search_placeholder: nil,
       to_boundaries: nil,
       loading: false
     )}
  end

  def do_handle_params(%{"id" => id} = params, url, socket) do
    {:noreply,
     socket
     |> assign(
       post_id: id,
       url: url,
       reply_to_id: e(params, "reply_to_id", id)
     )
     |> Bonfire.Social.Objects.LiveHandler.load_object_assigns()}
  end

  def do_handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> redirect_to(path(:write))}
  end

  def handle_params(params, uri, socket) do
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
