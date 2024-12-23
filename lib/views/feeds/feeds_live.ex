defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler
  alias Bonfire.UI.Social.FeedLive

  declare_extension("Social UI",
    icon: "ph:rss-simple-bold",
    # emoji: "📰",
    description:
      l(
        "User interfaces for basic social networking functionality, such as feeds and discussions."
      ),
    # exclude_from_nav: true
    # FIXME: should only include modules from current extension
    default_nav: [
      Bonfire.UI.Social.FeedsLive,
      # Bonfire.UI.Files.Web.MediaFeedLive,
      Bonfire.Search.Web.SearchLive,
      # Bonfire.UI.Social.ExploreLive,
      # Bonfire.UI.Social.Feeds.LocalLive,
      # Bonfire.UI.Social.Feeds.FederationLive,
      Bonfire.UI.Reactions.BookmarksLive,
      # Bonfire.UI.Social.Feeds.LikesLive,
      Bonfire.UI.Messages.MessagesLive,
      Bonfire.UI.Social.NotificationsFeedLive,
      Bonfire.UI.Me.ProfileLive,
      Bonfire.UI.Groups.ExploreLive,
      Bonfire.UI.Groups.SidebarGroupsLive
    ]
  )

  # declare_nav_link(l("My feed"), page: "feed", icon: "heroicons-solid:newspaper")
  declare_nav_link(
    [
      # NOTE: sticky feed, see https://github.com/bonfire-networks/bonfire-app/issues/901
      # {
      #   l("Feed"),
      #   # icon: "carbon:home",
      #   # icon_active: "carbon:home",
      #   page: "feed",
      #   icon: "ph:rss-simple-bold",
      #   href: "/feed",
      #   phx_hook: "Bonfire.UI.Common.PreviewContentLive#PreviewExtra"
      #   #  href: &nav_link_feed/1
      # },
      {l("Activities"),
       page: "activities", href: "/feed/my", icon: "carbon:explore", icon_active: "carbon:explore"}
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
       page: :explore,
       page_title: l("Activities"),
       page_header_icon: "carbon:home",
       feed: nil,
       page_info: nil,
       no_header: false,
       no_index: true,
       loading: true,
       feed_id: nil,
       feed_title: nil,
       feed_ids: nil,
       feed_filters: [],
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
            class: "btn-sm max-w-[100px] hidden md:inline-flex btn btn-primary"
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
       ]
     )}
  end

  # defp from_socket do
  #   to_options(socket) ++ [feed_filters: %{object_types: params["type"]}]
  # end

  def handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["federation", "fediverse", "remote"] do
    set_feed_assigns({:fediverse, params}, socket)
  end

  # def handle_params(%{"tab" => "explore" = _tab} = params, _url, socket) do
  #   if module_enabled?(Bonfire.Social.Pins, socket) and
  #        Bonfire.Common.Settings.get(
  #          [Bonfire.UI.Social.FeedsLive, :curated],
  #          false,
  #          assigns(socket)
  #        ) do
  #     set_feed_assigns({:curated, params}, socket)
  #   else
  #     set_feed_assigns({:explore, params}, socket)
  #   end
  # end
  def handle_params(%{"tab" => "explore" = _tab} = params, _url, socket) do
    # if module_enabled?(Bonfire.Social.Pins, socket) and
    #      Bonfire.Common.Settings.get(
    #        [Bonfire.UI.Social.FeedsLive, :curated],
    #        false,
    #        assigns(socket)
    #      ) do
    #   set_feed_assigns({:curated, params}, socket)
    # else
    set_feed_assigns({:explore, params}, socket)
    # end
  end

  def handle_params(%{"tab" => "my" = _tab} = params, _url, socket) do
    set_feed_assigns({:my, params}, socket)
  end

  def handle_params(%{"tab" => "curated" = _tab} = params, _url, socket) do
    set_feed_assigns({:curated, params}, socket)
  end

  def handle_params(%{"tab" => "local" = _tab} = params, _url, socket) do
    set_feed_assigns({:local, params}, socket)
  end

  def handle_params(%{"tab" => "likes" = _tab} = params, _url, socket) do
    set_feed_assigns({:likes, params}, socket)
  end

  def handle_params(%{"tab" => "flags" = _tab} = params, _url, socket) do
    set_feed_assigns({:flags, params}, socket)
  end

  def handle_params(params, _url, socket) do
    set_feed_assigns(
      {e(assigns(socket), :live_action, :default), params},
      socket
    )
  end

  def tabs(_page, context) do
    # disabled hiding of remote tab because it is also useful to find remote activities that were looked up manually
    # case Bonfire.Social.federating?(current_user(context)) do
    #   true ->
    # if current_user_id(context) do
    if module_enabled?(Bonfire.Social.Pins, context) and
         Bonfire.Common.Settings.get(
           [Bonfire.UI.Social.FeedsLive, :curated],
           false,
           context
         ) do
      [
        my: l("Following"),
        curated: l("Curated"),
        local: l("Local"),
        fediverse: l("Remote")
      ]
    else
      [
        my: l("Following"),
        explore: l("All"),
        local: l("Local"),
        fediverse: l("Remote")
      ]
    end

    # else

    #   [curated: l("Curated"), local: l("Local"), fediverse: l("Remote")]
    # end
  end

  def set_feed_assigns(feed_meta, socket) do
    debug(feed_meta)

    {:noreply,
     LiveHandler.feed_default_assigns(feed_meta, socket)
     |> debug("feed_default_assigns")
     |> assign(socket, ...)
     |> assign(..., FeedLive.maybe_widgets(e(..., :assigns, nil)))}
  end
end
