defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.UI.Social.FeedLive
  alias Bonfire.UI.Social.FeedController

  declare_extension(l("Social UI"),
    icon: "ph:rss-simple-duotone",
    # emoji: "📰",
    description:
      l(
        "User interfaces for basic social networking functionality, such as feeds and discussions."
      ),
    # exclude_from_nav: true
    # FIXME: should only include modules from current extension?
    # FIXME: these should be set somewhere in config
    default_nav: [
      Bonfire.Web.Views.DashboardLive,
      Bonfire.UI.Social.FeedsNavLinkLive,
      Bonfire.UI.Social.FeedsLive,
      # moved to right sidebar as WidgetFeedsLive
      Bonfire.UI.Social.FeedsNavLive,
      Bonfire.Search.Web.SearchLive,
      Bonfire.UI.Messages.MessagesLive,
      # Bonfire.UI.Social.NotificationsFeedLive,
      Bonfire.UI.Me.ProfileLive,
      # Bonfire.UI.Groups.ExploreLive,
      # Bonfire.UI.Boundaries.MyCirclesPageLive,
      Bonfire.UI.Groups.SidebarGroupsLive,
      Bonfire.PanDoRa.Components.SidebarPandoraLive
    ]
  )

  declare_nav_link(l("Notifications"),
    icon: "ph:bell-fill",
    page: "notifications",
    href: "/notifications",
    badge: [
      id: :notifications,
      feed_key: :notifications_id
    ]
  )

  # declare_nav_link(
  #   l("Feeds"),
  #   %{
  #     page: "feed",
  #     icon: "ph:rss-simple-fill",
  #     href: &nav_link_feed/1,
  #     #  TODO: these should be generated from preset filters and settings
  #     sub_links: [
  #       {l("Following"), page: "following", href: "/feed/my", icon: "ph:house-fill"},
  #       {l("Explore"), page: "explore", href: "/feed/explore", icon: "carbon:explore"},
  #       {l("Local"),
  #        page: "local", href: "/feed/local", icon: "material-symbols:camping-rounded"},
  #       {l("Remote"), page: "remote", href: "/feed/remote", icon: "el:network"},
  #       {l("Posts"),
  #        page: "posts", href: "/feed/posts", icon: "ri:chat-2-line", icon_active: "ri:chat-2-fill"},
  #       # {l("Discussions"),
  #       #  page: "discussions",
  #       # #  href: &nav_link_discussions/1,
  #       #  icon: "ri:discuss-line"},
  #       {l("Bookmarks"),
  #        page: "bookmarks", href: "/feed/bookmarks", icon: "ph:bookmark-fill-filled"},
  #       {l("Likes"), page: "likes", href: "/feed/likes", icon: "ph:fire-fill"}
  #     ]
  #   }
  # )

  # def nav_link_feed(context),
  #   do:
  #     "/feed/#{Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], nil,
  #     context: context,
  #     name: l("Default Feed"),
  #     description: l("Default feed to display when visiting the feed page."))}"

  # def nav_link_posts(%{current_params: %{"tab" => tab}}) when not is_nil(tab),
  #   do: "/feed/#{tab}/posts"

  # def nav_link_posts(_), do: "/feed/filter/posts"

  # def nav_link_discussions(%{current_params: %{"tab" => tab}}) when not is_nil(tab),
  #   do: "/feed/#{tab}/discussions"

  # def nav_link_discussions(_), do: "/feed/filter/discussions"

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.LoadCurrentUserCircles
            ]}

  def mount(_params, session, socket) do
    import Bonfire.UI.Common.Timing

    time_section :lv_feeds_mount do
      {:ok,
       socket
       |> assign(
         selected_tab: nil,
         #  page: :explore,
         page_title: nil,
         page_header_icon: "ph:house-fill",
         feed: nil,
         page_info: nil,
         no_header: false,
         no_index: true,
         loading: true,
         back: true,
         feed_id: nil,
         feed_count: nil,
         feed_title: nil,
         feed_ids: nil,
         feed_filters: %{},
         hide_filters: false,
         tab_path_suffix: nil,
         feed_component_id: nil,
         # set per feed by the preset's assigns, but needed before the first load too
         enable_marker: nil,
         feedback_title: l("Your feed is empty"),
         feedback_message:
           l("You can start by following some people, or writing a new post yourself."),
         page_header_aside: [
           #  {Bonfire.UI.Common.SmartInputButtonLive,
           #   [
           #     prompt: l("Compose"),
           #     class: "btn-sm hidden md:inline-flex btn btn-primary"
           #   ]}
         ],
         sidebar_widgets: [],
         preferences_widget_id: nil,
         maybe_rss_or_atom: maybe_rss_or_atom(session)
       )}
    end
  end

  def handle_params(
        %{"after" => _cursor_after} = attrs,
        url,
        socket
      ) do
    LiveHandler.handle_params(attrs, url, prepare_feed_socket(attrs, socket))
  end

  def handle_params(%{"tab" => tab} = params, _url, socket) do
    set_feed_assigns(maybe_to_atom(tab), params, socket)
  end

  # a notifications category chip, eg. `/notifications/likes`: a chip key, a chip alias, or any verb
  def handle_params(%{"notification_category" => segment} = params, _url, socket) do
    case Bonfire.UI.Social.NotificationFiltersLive.resolve_segment(segment, socket) do
      {chip, preset, filters} ->
        handle_notification_chip(chip, preset, filters, params, socket)

      nil ->
        {:noreply, push_patch(socket, to: "/notifications")}
    end
  end

  # no segment: the default chip, which is the unfiltered feed
  def handle_params(params, _url, %{assigns: %{live_action: :notifications}} = socket) do
    handle_notification_chip(
      nil,
      Bonfire.UI.Social.NotificationFiltersLive.default_preset(),
      %{activity_types: []},
      params,
      socket
    )
  end

  # display switches save as they are flipped (`SettingsToggleLive`), and this re-queries the feed once for however many changed, rather than reloading on every toggle
  def handle_event("apply_notification_display", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Bonfire.UI.Social.NotificationFiltersLive.path_for(
           assigns(socket)[:selected_tab],
           socket
         )
     )}
  end

  defp handle_notification_chip(chip, preset, filters, params, socket) do
    # a mounted `FeedLive` ignores changed assigns ("skip replacing feed unless it was loading"), so a patch has to tell the component what changed. NOTE: giving each chip its own component id instead was tried and is worse, as the fresh component mounts and loads UNFILTERED
    mounted_feed_id = assigns(socket)[:feed_component_id]

    # Every chip rebuilds the page's feed assigns, as a first load does: asking the mounted component to reload itself instead (`apply_filters`) inserts the right rows but they stay invisible until something rebuilds those assigns, which is why visiting the flags chip made every later chip work. Per-chip component ids were tried too and are worse, as a fresh component mounts and loads unfiltered
    # this user's display switches: filters go in with the chip's, assigns after the feed ones (which carry the preset's defaults for the same keys). The chip's own types are what it asks for, so a hidden category's chip still shows it
    {display_filters, display_assigns} =
      Bonfire.UI.Social.NotificationPreferencesLive.display_overrides(
        socket,
        e(filters, :activity_types, [])
      )

    chip_filters = Map.merge(Map.new(filters), display_filters)

    params =
      params
      |> Map.delete("notification_category")
      |> Map.merge(chip_filters)

    # `selected_tab` after the feed assigns, which set it to the feed name
    with {:noreply, socket} <- set_feed_assigns(preset, params, socket) do
      socket = assign(socket, display_assigns)

      # a different preset (the flags chip) also needs the mounted component switched over to it, with the narrowing, since `apply_preset` alone would reload that preset unfiltered. The display switches go with it, or the component reloads without them and the categories this user hid come back on every chip click
      if mounted_feed_id,
        do:
          send_update(Bonfire.UI.Social.FeedLive,
            id: mounted_feed_id,
            apply_preset: preset,
            apply_filters: chip_filters
          )

      {:noreply, assign(socket, selected_tab: chip)}
    end
  end

  # def handle_params(%{"tab" => "explore" = _tab} = params, _url, socket) do
  #   if module_enabled?(Bonfire.Social.Pins, socket) and
  #        Bonfire.Common.Settings.get(
  #          [Bonfire.UI.Social.FeedsLive, :curated],
  #          false,
  #          assigns(socket)
  #        ) do
  #     set_feed_assigns(:curated, params, socket)
  #   else
  #     set_feed_assigns(:explore, params, socket)
  #   end
  # end
  # def handle_params(%{"tab" => "explore" = _tab} = params, _url, socket) do
  #   # if module_enabled?(Bonfire.Social.Pins, socket) and
  #   #      Bonfire.Common.Settings.get(
  #   #        [Bonfire.UI.Social.FeedsLive, :curated],
  #   #        false,
  #   #        assigns(socket)
  #   #      ) do
  #   #   set_feed_assigns(:curated, params, socket)
  #   # else
  #   set_feed_assigns(:explore, params, socket)
  #   # end
  # end

  def handle_params(params, _url, socket) do
    set_feed_assigns(
      params,
      socket
    )
  end

  # def tabs(_page, context) do
  #   # disabled hiding of remote tab because it is also useful to find remote activities that were looked up manually
  #   # case Bonfire.Social.federating?(current_user(context)) do
  #   #   true ->
  #   # if current_user_id(context) do
  #   if module_enabled?(Bonfire.Social.Pins, context) and
  #        Bonfire.Common.Settings.get(
  #          [Bonfire.UI.Social.FeedsLive, :curated],
  #          false,
  #          context
  #        ) do
  #     [
  #       my: l("Following"),
  #       curated: l("Curated"),
  #       local: l("Local"),
  #       fediverse: l("Remote")
  #     ]
  #   else
  #     [
  #       my: l("Following"),
  #       explore: l("All"),
  #       local: l("Local"),
  #       fediverse: l("Remote")
  #     ]
  #   end

  # else

  #   [curated: l("Curated"), local: l("Local"), fediverse: l("Remote")]
  # end
  # end

  def set_feed_assigns(feed \\ nil, attrs, socket) do
    feed_str = to_string(feed)
    ext = Path.extname(feed_str)

    cond do
      ext in [".rss", ".atom"] ->
        format = String.trim_leading(ext, ".")
        base = Path.rootname(feed_str)
        FeedController.feed_redirect(socket, format, base, attrs)

      format = assigns(socket)[:maybe_rss_or_atom] ->
        FeedController.feed_redirect(socket, format, feed, attrs)

      true ->
        {:noreply, prepare_feed_socket(feed, attrs, socket)}
    end
  end

  def prepare_feed_socket(feed \\ nil, attrs, socket) do
    debug(feed, "feed")
    debug(attrs, "attrs")

    import Bonfire.UI.Common.Timing

    filters = input_to_atoms(attrs)

    # Wrap single object_types string from URL param into a list, since feed_filters expects lists
    filters =
      case filters do
        %{object_types: types} when is_binary(types) ->
          Map.put(filters, :object_types, List.wrap(Types.maybe_to_atom(types)))

        _ ->
          filters
      end

    feed_assigns =
      time_section :lv_feed_default_assigns do
        LiveHandler.feed_default_assigns(
          {feed || e(assigns(socket), :live_action, :default), filters},
          socket
        )
      end

    socket =
      socket
      |> assign(feed_assigns |> debug("feed_default_assigns"))
      |> assign_feed_heading()
      |> maybe_clear_badge_on_visit()

    configure_widgets(socket)
  end

  defp assign_feed_heading(socket) do
    notifications? = socket.assigns[:live_action] == :notifications

    header_aside =
      Enum.reject(socket.assigns.page_header_aside, fn {module, _opts} ->
        module in [
          Bonfire.UI.Social.FeedSettingsButtonLive,
          Bonfire.UI.Social.NotificationPreferencesButtonLive
        ]
      end)

    button =
      if notifications?,
        do: Bonfire.UI.Social.NotificationPreferencesButtonLive,
        else: Bonfire.UI.Social.FeedSettingsButtonLive

    assign(socket,
      page_title: socket.assigns[:page_title] || l("Feed"),
      page_header_aside: header_aside ++ [{button, []}]
    )
  end

  def handle_info({:feed_filters_changed, component_id, feed_name, filters}, socket) do
    if component_id == socket.assigns.feed_component_id and socket.assigns.preferences_widget_id do
      Phoenix.LiveView.send_update(Bonfire.UI.Social.WidgetCustomizeFeedLive,
        id: socket.assigns.preferences_widget_id,
        preferences: %{
          feed_name: feed_name,
          feed_filters: filters
        }
      )
    end

    {:noreply, socket}
  end

  defp configure_widgets(socket) do
    feed_name = FeedLive.feed_name(assigns(socket))

    {preferences, description} =
      case Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, assigns(socket)) do
        {:ok, _preset} when feed_name != :curated ->
          preferences =
            if socket.assigns.hide_filters do
              []
            else
              [
                {Bonfire.UI.Social.WidgetCustomizeFeedLive,
                 [
                   id: "feed_preferences_#{socket.assigns.feed_component_id}",
                   event_target: "##{socket.assigns.feed_component_id}",
                   feed_id: socket.assigns.feed_id,
                   feed_name: feed_name,
                   feed_filters: socket.assigns.feed_filters
                 ]}
              ]
            end

          {preferences, [{Bonfire.UI.Social.WidgetFeedDescriptionLive, [feed_name: feed_name]}]}

        _ ->
          {[], []}
      end

    assign(socket,
      preferences_widget_id:
        if(preferences != [] and not is_nil(current_user_id(socket)),
          do: "feed_preferences_#{socket.assigns.feed_component_id}"
        ),
      sidebar_widgets: [
        users: [secondary: description ++ preferences ++ [{Bonfire.Tag.Web.WidgetTagsLive, []}]],
        guests: [secondary: description]
      ]
    )
  end

  defp maybe_clear_badge_on_visit(socket) do
    if e(assigns(socket), :feed_name, nil) == :notifications do
      LiveHandler.mark_feed_seen_on_visit(:notifications, socket)
    else
      # Reset the guard so coming back to an auto-clear feed re-fires
      # (otherwise navigating away and back would stale-skip and miss
      # any unread that arrived in the gap).
      if e(assigns(socket), :badge_cleared_for_feed, nil),
        do: assign(socket, :badge_cleared_for_feed, nil),
        else: socket
    end
  end

  defp maybe_rss_or_atom(session) do
    cond do
      http_accepts?(session, "application/rss+xml") -> "rss"
      http_accepts?(session, "application/atom+xml") -> "atom"
      true -> nil
    end
  end
end
