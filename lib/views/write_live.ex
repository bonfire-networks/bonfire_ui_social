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

  def handle_params(%{"share_url" => url, "share_name" => name} = params, _url, socket) do
    {:noreply,
     socket
     |> update(
       :smart_input_opts,
       fn opts -> Keyword.put(opts, :text, "[#{name}](#{url}) #{params["text"]} ") end
     )}
  end

  def handle_params(%{"share_url" => url} = params, _url, socket) do
    {:noreply,
     socket
     |> update(
       :smart_input_opts,
       fn opts -> Keyword.put(opts, :text, "#{url} #{params["text"]} ") end
     )}
  end

  def handle_params(%{"text" => "http" <> _ = url, "share_name" => name} = params, _url, socket) do
    # special case for no url but text that starts with http
    {:noreply,
     socket
     |> update(
       :smart_input_opts,
       fn opts -> Keyword.put(opts, :text, "[#{name}](#{url}) ") end
     )}
  end

  def handle_params(%{"text" => text} = params, _url, socket) do
    {:noreply,
     socket
     |> update(
       :smart_input_opts,
       fn opts -> Keyword.put(opts, :text, "#{text} ") end
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
