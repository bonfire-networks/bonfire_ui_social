defmodule Bonfire.UI.Social.WriteLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  # declare_nav_link("Link to compose page",
  #   text: l("Compose"),
  #   icon: "heroicons-solid:PencilAlt",
  #   exclude_from_nav: true
  # )

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      # LivePlugs.LoadCurrentUserCircles,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Write"),
       page: "write",
       create_object_type: maybe_to_atom(e(session, "create_object_type", nil)),
       smart_input_opts: %{
         open: true,
         as: :modal,
         hide_buttons: false,
         text: e(session, "smart_input_text", nil)
       },
       reply_to_id: e(session, "reply_to_id", nil),
       context_id: e(session, "context_id", nil),
       to_boundaries: nil,
       to_circles: [],
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
       ]
     )}
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__
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
