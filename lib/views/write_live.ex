defmodule Bonfire.UI.Social.WriteLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Common.LivePlugs

  # declare_nav_link("Link to compose page",
  #   text: l("Compose"),
  #   icon: "heroicons-solid:PencilAlt",
  #   exclude_from_nav: true
  # )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.UserRequired]}

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Write"),
       page: "write",
       create_object_type: maybe_to_atom(e(session, "create_object_type", nil)),
       smart_input_opts: %{
         open: true,
         as: :focused,
         hide_buttons: false,
         text_suggestion: e(session, "smart_input_text", nil)
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
