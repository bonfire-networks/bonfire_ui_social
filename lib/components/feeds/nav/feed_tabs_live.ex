defmodule Bonfire.UI.Social.FeedTabsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop selected_feed, :any, default: nil

  @doc "Builds a tab's link from its slug (default `/feed/<slug>`)."
  prop path, :fun, default: nil

  @doc "Sticks under the page header; off where the tabs sit mid-page."
  prop sticky, :boolean, default: true

  @doc "Presets already loaded with `FeedNavigation.list_presets/1`, if any."
  prop available, :list, default: nil

  @doc "Renders the user's visible feed presets as navigation beneath the page header."
  def render(assigns) do
    path = assigns.path || (&FeedNavigation.build_path/1)
    selected = to_string(assigns.selected_feed)

    presets =
      (assigns.available || FeedNavigation.list_presets(current_user: current_user(assigns)))
      # the open feed keeps its tab even if hidden from the nav
      |> Enum.filter(fn {slug, preset} ->
        preset[:exclude_from_nav] == false or to_string(slug) == selected
      end)
      |> Enum.map(fn {slug, preset} ->
        %{
          slug: to_string(slug),
          name: FeedNavigation.get_name(preset, slug),
          href: path.(slug),
          active?: to_string(slug) == selected
        }
      end)

    assigns
    |> assign(presets: presets)
    |> render_sface()
  end
end
