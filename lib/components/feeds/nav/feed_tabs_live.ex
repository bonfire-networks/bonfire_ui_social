defmodule Bonfire.UI.Social.FeedTabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop selected_feed, :any, default: nil

  @doc "Renders the user's visible feed presets as navigation beneath the page header."
  def render(assigns) do
    presets =
      FeedNavigation.list_presets(current_user: current_user(assigns))
      |> Enum.filter(fn {_slug, preset} -> preset[:exclude_from_nav] == false end)
      |> Enum.map(fn {slug, preset} ->
        %{
          slug: to_string(slug),
          name: FeedNavigation.get_name(preset, slug),
          icon: preset[:icon] || "ph:rss-simple",
          href: FeedNavigation.build_path(slug),
          active?: to_string(slug) == to_string(assigns.selected_feed)
        }
      end)

    assigns
    |> assign(presets: presets)
    |> render_sface()
  end
end
