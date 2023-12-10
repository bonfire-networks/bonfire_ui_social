defmodule Bonfire.UI.Social.Feeds.BookmarksLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  declare_nav_link(l("Bookmarks"),
    page: "bookmarks",
    href: "/bookmarks",
    icon: "carbon:bookmark",
    icon_active: "carbon:bookmark-filled"
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.UserRequired]}

  def mount(_params, _session, socket) do
    current_user = current_user_required!(socket)

    %{edges: feed, page_info: page_info} =
      Bonfire.Social.Bookmarks.list_my(current_user: current_user)

    # |> debug()

    {:ok,
     socket
     |> assign(
       feed: feed,
       page_info: page_info,
       showing_within: :bookmarks,
       loading: false,
       page: "bookmarks",
       feed_name: :bookmarks,
       feed_title: l("Bookmarks"),
       no_header: true
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
