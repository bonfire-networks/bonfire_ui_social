defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.Social.Feeds.LiveHandler

  declare_extension("Social",
    icon: "noto:newspaper",
    # exclude_from_nav: true
    default_nav: [
      Bonfire.UI.Social.FeedsLive,
      Bonfire.UI.Me.ProfileLive,
      Bonfire.UI.Social.Feeds.LocalLive,
      Bonfire.UI.Social.Feeds.FederationLive,
      Bonfire.UI.Social.Feeds.LikesLive
    ]
  )

  # declare_nav_link(l("My feed"), page: "feed", icon: "heroicons-solid:newspaper")
  declare_nav_link([
    {l("Feeds"), page: "feed", icon: "heroicons-solid:newspaper"},
    {l("Posts"),
     page: "posts", href: "/feed/filter/posts", icon: "heroicons:pencil-square-20-solid"},
    {l("Discussions"),
     page: "discussions",
     href: "/feed/filter/discussions",
     icon: "heroicons:chat-bubble-left-right-20-solid"}
  ])

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.UserRequired,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(params, _session, socket) do
    {:ok,
     socket
     |> assign(
       selected_tab: "feed",
       page: "feed",
       page_title: l("My feed"),
       feed: nil,
       page_info: nil,
       loading: true,
       feed_id: nil,
       feed_title: nil,
       feed_ids: nil,
       feed_component_id: :feeds,
       feedback_title: l("Your feed is empty"),
       feedback_message:
         l("You can start by following some people, or writing a new post yourself."),
       sidebar_widgets: [
         users: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: nil
         ]
       ]
     )}
  end

  # defp from_socket do
  #   to_options(socket) ++ [feed_filters: %{object_type: params["type"]}]
  # end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["federation", "fediverse", "remote"] do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async({:fediverse, params}, socket))}
  end

  def do_handle_params(%{"tab" => "local" = tab} = params, _url, socket) do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async({:local, params}, socket))}
  end

  def do_handle_params(%{"tab" => "likes" = tab} = params, _url, socket) do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async({:likes, params}, socket))}
  end

  def do_handle_params(params, _url, socket) do
    # debug("param")
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async({:default, params}, socket))}
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
