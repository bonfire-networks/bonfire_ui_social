defmodule Bonfire.UI.Social.Feeds.LikesLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  declare_nav_link(l("Favourites"),
    page: "favourites",
    href: "/feed/likes",
    icon: "mingcute:fire-line",
    icon_active: "mingcute:fire-fill"
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.UserRequired]}

  def mount(_params, _session, socket) do
    current_user = current_user_required!(socket)

    %{edges: feed, page_info: page_info} =
      Bonfire.Social.Likes.list_my(current_user: current_user)

    # |> debug()

    {:ok,
     socket
     |> assign(
       feed: feed,
       page_info: page_info,
       showing_within: :likes,
       loading: false,
       page: "favourites",
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
       page_title: l("My Favourites")
     )}
  end

  # def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def do_handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

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
