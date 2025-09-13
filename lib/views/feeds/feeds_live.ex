defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.UI.Social.FeedLive
  alias Bonfire.UI.Social.FeedController
  alias Bonfire.UI.Common.SmartInput.LiveHandler, as: SmartInputLiveHandler

  declare_extension("Social UI",
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
      Bonfire.UI.Social.FeedsLive,
      Bonfire.UI.Social.FeedsNavLive,
      # Bonfire.UI.Files.Web.MediaFeedLive,
      Bonfire.Search.Web.SearchLive,
      # Bonfire.UI.Social.ExploreLive,
      # Bonfire.UI.Social.Feeds.LocalLive,
      # Bonfire.UI.Social.Feeds.FederationLive,
      # Bonfire.UI.Reactions.BookmarksLive,
      # Bonfire.UI.Social.Feeds.LikesLive,
      Bonfire.UI.Messages.MessagesLive,
      # Bonfire.UI.Social.NotificationsFeedLive,
      Bonfire.UI.Me.ProfileLive,
      # Bonfire.UI.Groups.ExploreLive,
      Bonfire.UI.Boundaries.SidebarCirclesLive,
      Bonfire.PanDoRa.Components.SidebarPandoraLive,
      Bonfire.UI.Groups.SidebarGroupsLive
    ]
  )

  declare_nav_link(l("Notifications"),
    icon: "ph:bell-duotone",
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
  #     icon: "ph:rss-simple-duotone",
  #     href: &nav_link_feed/1,
  #     #  TODO: these should be generated from preset filters and settings
  #     sub_links: [
  #       {l("Following"), page: "following", href: "/feed/my", icon: "carbon:home"},
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
  #        page: "bookmarks", href: "/feed/bookmarks", icon: "ph:bookmark-duotone-filled"},
  #       {l("Likes"), page: "likes", href: "/feed/likes", icon: "ph:fire-duotone"}
  #     ]
  #   }
  # )

  def nav_link_feed(context),
    do:
      "/feed/#{Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], nil,
      context: context,
      name: l("Default Feed"),
      description: l("Default feed to display when visiting the feed page."))}"

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
    {:ok,
     socket
     |> assign(
       selected_tab: nil,
       #  page: :explore,
       page_title: l("Activities"),
       page_header_icon: "carbon:home",
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
       tab_path_suffix: nil,
       feed_component_id: nil,
       feedback_title: l("Your feed is empty"),
       feedback_message:
         l("You can start by following some people, or writing a new post yourself."),
       nav_items: Bonfire.Common.ExtensionModule.default_nav(),
       page_header_aside: [
         {Bonfire.UI.Common.SmartInputButtonLive,
          [
            prompt: l("Compose"),
            class: "btn-sm hidden md:inline-flex btn btn-primary"
          ]}
       ],
       sidebar_widgets: [
         users: [
           secondary: [
             #  {Bonfire.UI.Social.WidgetFeedLive, [event_target: ]},
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: [{Bonfire.Tag.Web.WidgetTagsLive, []}]
         ]
       ],
       maybe_rss_or_atom: maybe_rss_or_atom(session)
     )}
  end

  # defp from_socket do
  #   to_options(socket) ++ [feed_filters: %{object_types: params["type"]}]
  # end

  # def handle_params(%{"compose" => "open"} = params, url, socket) do
  #   # Remove the compose param to avoid polluting downstream logic
  #   params_without_compose = Map.delete(params, "compose")

  #   # Call set_feed_assigns directly instead of handle_params to avoid recursion
  #   {:noreply, updated_socket} = set_feed_assigns(params_without_compose, socket)

  #   # Set smart_input_opts in socket assigns for initial render
  #   updated_socket = assign(updated_socket, smart_input_opts: %{open: true})

  #   # Send to PersistentLive for initial render (works with PhoenixTest)
  #   Bonfire.UI.Common.PersistentLive.maybe_send_assigns(assigns(updated_socket))

  #   # Also use SmartInputLiveHandler for dynamic updates (works in browser)
  #   SmartInputLiveHandler.assign_open(updated_socket)

  #   IO.inspect("Opened composer via both PersistentLive assigns and SmartInputLiveHandler")

  #   {:noreply, updated_socket}
  # end

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

      format = socket.assigns[:maybe_rss_or_atom] ->
        FeedController.feed_redirect(socket, format, feed, attrs)

      true ->
        {:noreply, prepare_feed_socket(feed, attrs, socket)}
    end
  end

  def prepare_feed_socket(feed \\ nil, attrs, socket) do
    debug(feed, "feed")
    debug(attrs, "attrs")

    socket
    |> assign(
      LiveHandler.feed_default_assigns(
        {feed || e(assigns(socket), :live_action, :default), input_to_atoms(attrs)},
        socket
      )
      |> debug("feed_default_assigns")
    )
    |> assign(..., FeedLive.maybe_widgets(assigns(...)))
  end

  defp maybe_rss_or_atom(session) do
    case Map.get(session, "accept_header") do
      accept_header when is_binary(accept_header) ->
        cond do
          String.contains?(accept_header, "application/rss+xml") -> "rss"
          String.contains?(accept_header, "application/atom+xml") -> "atom"
          true -> nil
        end

      _ ->
        nil
    end
  end
end
