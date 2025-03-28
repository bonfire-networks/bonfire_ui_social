defmodule Bonfire.UI.Social.WriteLive do
  use Bonfire.UI.Common.Web, :surface_live_view

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
       page_title: l("Write something"),
       page: "write",
       without_sidebar: true,
       without_secondary_widgets: true,
       smart_input_opts: [
         create_object_type: maybe_to_atom(e(session, "create_object_type", nil)),
         inline_only: true,
         hide_buttons: true,
         text: e(session, "smart_input_text", nil)
       ],
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
end
