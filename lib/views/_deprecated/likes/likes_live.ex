defmodule Bonfire.UI.Social.Feeds.LikesLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  # declare_nav_link(l("Favourites"),
  #   page: "likes",
  #   icon: "bi:stars"
  # )

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
    current_user = current_user_required!(socket)

    %{edges: feed, page_info: page_info} =
      Bonfire.Social.Likes.list_my(current_user: current_user)

    # |> debug()

    {:ok,
     socket
     |> assign(
       feed: Bonfire.Social.Feeds.LiveHandler.preloads(feed, socket),
       page_info: page_info,
       showing_within: :likes,
       loading: false,
       page: "likes",
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
       page_title: l("My Favourites")
     )}
  end

  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end

  # def handle_params(%{} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      current_user: Fake.user_live()
  #    )}
  # end

  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
