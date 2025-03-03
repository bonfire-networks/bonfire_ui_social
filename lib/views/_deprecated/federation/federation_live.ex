defmodule Bonfire.UI.Social.Feeds.FederationLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Social.Feeds.LiveHandler

  declare_nav_link(l("Remote"),
    page: "federation",
    href: "/feed/federation",
    icon: "el:network"
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(LiveHandler.feed_default_assigns(:remote, socket))
     |> assign(
       page: "federation",
       page_title: l("Federation")
     )}
  end
end
