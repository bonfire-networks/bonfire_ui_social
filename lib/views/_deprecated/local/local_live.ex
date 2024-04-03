defmodule Bonfire.UI.Social.Feeds.LocalLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler

  # declare_nav_link(l("Local"),
  #   href: "/feed/local",
  #   page: "local",
  #   # icon: "material-symbols:camping-rounded"
  # )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(LiveHandler.feed_default_assigns(:local, socket))
     |> assign(
       page: "local",
       #  without_sidebar: true,
       page_title: l("Local"),
       selected_tab: "local"
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
end
