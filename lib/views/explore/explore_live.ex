defmodule Bonfire.UI.Social.ExploreLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  declare_nav_link(l("Explore"), page: "Explore", icon: "ri:safari-line")

  on_mount {LivePlugs,
            [Bonfire.UI.Me.LivePlugs.LoadCurrentUser, Bonfire.UI.Me.LivePlugs.AccountRequired]}

  def mount(_params, _session, socket) do
    current_user = current_user_required!(socket)
    # |> debug("current_user")

    # feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, socket)
    # TODO: avoid two queries for feed_id?
    feed = []

    {:ok,
     socket
     |> assign(
       page: "explore",
       selected_tab: "explore",
       #  without_sidebar: true,
       page_header_icon: "ri:safari-line",
       page_title: l("Explore"),
       feedback_title: l("You have no activities"),
       feedback_message:
         l(
           "Did you know you can customise which activities you want to be notified for in your settings ?"
         ),
       current_user: current_user,
       feed_id: :notifications,
       feed: e(feed, :edges, []),
       page_info: e(feed, :page_info, []),
       loading: false,
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
