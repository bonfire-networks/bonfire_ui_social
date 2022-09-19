defmodule Bonfire.UI.Social.FeedsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.Social.Feeds.LiveHandler

  declare_extension("Social",
    icon: "noto:newspaper",
    exclude_from_nav: true,
    default_nav: [
      Bonfire.UI.Social.FeedsLive,
      Bonfire.UI.Social.Feeds.LocalLive,
      Bonfire.UI.Social.Feeds.FederationLive,
      Bonfire.UI.Social.Feeds.LikesLive
    ]
  )

  declare_nav_link(l("Recent"), icon: "heroicons-solid:newspaper")

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
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
       page_header_drawer: true,
       feed_id: nil,
       feed_ids: nil,
       feedback_title: l("Your feed is empty"),
       feedback_message:
         l("You can start by following some people, or writing a new post yourself."),
       sidebar_widgets: [
         users: [
           secondary: [
             {Bonfire.UI.Social.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: [
             {Bonfire.UI.Social.WidgetTagsLive, []}
           ]
         ]
       ]
     )}
  end

  def do_handle_params(%{"tab" => "federation" = tab} = params, _url, socket) do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:fediverse, socket))}
  end

  def do_handle_params(%{"tab" => "local" = tab} = params, _url, socket) do
    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:local, socket))}
  end

  def do_handle_params(_params, _url, socket) do
    # debug("param")

    {:noreply, assign(socket, LiveHandler.feed_assigns_maybe_async(:default, socket))}
  end

  # defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers
  def handle_params(params, uri, socket) do
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
