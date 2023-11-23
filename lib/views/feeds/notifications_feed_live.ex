defmodule Bonfire.UI.Social.NotificationsFeedLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  declare_nav_link(l("Notifications"),
    icon: "carbon:notification",
    icon_active: "carbon:notification",
    page: "notifications",
    badge: [
      id: :notifications,
      feed_key: :notifications_id
    ]
  )

  on_mount {LivePlugs,
            [Bonfire.UI.Me.LivePlugs.LoadCurrentUser, Bonfire.UI.Me.LivePlugs.AccountRequired]}

  def mount(_params, _session, socket) do
    current_user = current_user_required!(socket)
    # |> debug("current_user")

    # feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, socket)
    # TODO: avoid two queries for feed_id?
    # feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: current_user)

    {:ok,
     socket
     |> assign(
       page: "notifications",
       selected_tab: "notifications",
       #  without_sidebar: true,
       page_header_icon: "carbon:notification",
       page_title: l("Notifications"),
       feedback_title: l("You have no notifications"),
       feedback_message:
         l(
           "Did you know you can customise which activities you want to be notified for in your settings ?"
         ),
       current_user: current_user,
       feed_id: :notifications,
       feed: nil,
       page_info: nil,
       #  feed: e(feed, :edges, []),
       #  page_info: e(feed, :page_info, []),
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
       ],
       page_header_aside: [
         {Bonfire.UI.Social.HeaderAsideNotificationsSeenLive,
          [
            feed_id: :notifications
          ]}
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
