defmodule Bonfire.UI.Social.Feeds.NotificationsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  declare_nav_link(l("Notifications"),
    icon: "heroicons-solid:Bell",
    badge: [
      id: :notifications,
      feed_key: :notifications_id
    ]
  )

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.AccountRequired,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, _session, socket) do
    current_user =
      current_user_required!(socket)
      |> info("current_user")

    # feed_id = Bonfire.Social.Feeds.my_feed_id(:notifications, socket)
    # TODO: avoid two queries for feed_id?
    feed = Bonfire.Social.FeedActivities.feed(:notifications, current_user: current_user)

    {:ok,
     socket
     |> assign(
       page: "notifications",
       selected_tab: "notifications",
       #  without_sidebar: true,
       page_title: l("Notifications"),
       feedback_title: l("You have no notifications"),
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
