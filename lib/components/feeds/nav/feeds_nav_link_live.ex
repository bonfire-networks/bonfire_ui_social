defmodule Bonfire.UI.Social.FeedsNavLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  declare_nav_link(l("Feeds"),
    icon: "ph:rss-duotone",
    page: "feeds",
    href: "/feed/my",
    href_prefix: "/feed"
  )

  def render(assigns), do: ~F""
end
