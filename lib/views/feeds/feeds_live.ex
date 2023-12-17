defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.UI.Social.FeedLive

  declare_extension("Social",
    # icon: "noto:newspaper",
    # emoji: "📰",
    # exclude_from_nav: true
    default_nav: [
      Bonfire.UI.Social.FeedsLive,
      Bonfire.Search.Web.SearchLive,
      # Bonfire.UI.Social.ExploreLive,
      # Bonfire.UI.Social.Feeds.LocalLive,
      # Bonfire.UI.Social.Feeds.FederationLive,
      Bonfire.UI.Social.Feeds.BookmarksLive,
      # Bonfire.UI.Social.Feeds.LikesLive,
      Bonfire.UI.Social.MessagesLive,
      Bonfire.UI.Social.NotificationsFeedLive,
      # Bonfire.UI.Me.ProfileLive,
      Bonfire.UI.Groups.SidebarGroupsLive
    ]
  )

  # declare_nav_link(l("My feed"), page: "feed", icon: "heroicons-solid:newspaper")
  declare_nav_link(
    [
      {
        l("My feed"),
        page: "feed", icon: "carbon:home", icon_active: "carbon:home", href: "/feed"
        #  href: &nav_link_feed/1
      },
      {l("Explore"),
       page: "explore",
       href: "/feed/explore",
       icon: "carbon:explore",
       icon_active: "carbon:explore"}
      # {l("Moderation"),
      # page: "moderation",
      # href: &nav_link_feed/1,
      # icon: "ri:seedling-line",
      # icon_active: "ri:seedling-fill"}
    ]
    # {l("Local"),
    # page: "feed",
    # href: &nav_link_feed/1,
    # icon: "material-symbols:camping-rounded",
    # icon_active: "ri:home-fill"},
    # {l("Remote"),
    # page: "feed",
    # href: &nav_link_feed/1,
    # icon: "el:network",
    # icon_active: "ri:home-fill"},

    # {l("Posts"), page: "posts", href: &nav_link_posts/1, icon: "ri:chat-2-line", icon_active: "ri:chat-2-fill"}
    # {l("Discussions"),
    #  page: "discussions", href: &nav_link_discussions/1, icon: "ri:discuss-line"}]
  )

  # def nav_link_feed(context), do: "/feed/#{Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], nil, context)}"

  # def nav_link_posts(%{current_params: %{"tab" => tab}}) when not is_nil(tab), do: "/feed/#{tab}/posts"
  # def nav_link_posts(_), do: "/feed/filter/posts"

  # def nav_link_discussions(%{current_params: %{"tab" => tab}}) when not is_nil(tab), do: "/feed/#{tab}/discussions"
  # def nav_link_discussions(_), do: "/feed/filter/discussions"

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       selected_tab: nil,
       page: "feed",
       page_title: l("Activities"),
       page_header_icon: "carbon:home",
       feed: nil,
       page_info: nil,
       no_header: true,
       no_index: true,
       loading: true,
       feed_id: nil,
       feed_title: nil,
       feed_ids: nil,
       tab_path_suffix: nil,
       feed_component_id: nil,
       feedback_title: l("Your feed is empty"),
       feedback_message:
         l("You can start by following some people, or writing a new post yourself."),
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
       ]
     )}
  end

  # defp from_socket do
  #   to_options(socket) ++ [feed_filters: %{object_type: params["type"]}]
  # end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["federation", "fediverse", "remote"] do
    set_feed_assigns({:fediverse, params}, socket)
  end

  def do_handle_params(%{"tab" => "explore" = _tab} = params, _url, socket) do
    if Bonfire.Common.Config.get(
         [Bonfire.UI.Social.FeedsLive, :curated],
         false
       ) &&
         Bonfire.Common.Settings.get(
           [Bonfire.UI.Social.FeedsLive, :curated],
           false,
           current_user(socket.assigns)
         ) do
      set_feed_assigns({:curated, params}, socket)
    else
      set_feed_assigns({:explore, params}, socket)
    end
  end

  def do_handle_params(%{"tab" => "curated" = _tab} = params, _url, socket) do
    set_feed_assigns({:curated, params}, socket)
  end

  def do_handle_params(%{"tab" => "local" = _tab} = params, _url, socket) do
    set_feed_assigns({:local, params}, socket)
  end

  def do_handle_params(%{"tab" => "likes" = _tab} = params, _url, socket) do
    set_feed_assigns({:likes, params}, socket)
  end

  def do_handle_params(%{"tab" => "flags" = _tab} = params, _url, socket) do
    set_feed_assigns({:flags, params}, socket)
  end

  def do_handle_params(params, _url, socket) do
    set_feed_assigns(
      {e(socket, :assigns, :live_action, :default), params},
      socket
    )
  end

  def set_feed_assigns(feed_meta, socket) do
    {:noreply,
     socket
     |> assign(LiveHandler.feed_default_assigns(feed_meta, socket))
     |> assign(..., FeedLive.maybe_widgets(e(..., :assigns, nil)))}
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__,
        &do_handle_params/3
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
