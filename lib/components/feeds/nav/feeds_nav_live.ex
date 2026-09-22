defmodule Bonfire.UI.Social.FeedsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop selected_tab, :any, default: nil

  declare_nav_component("Links to user's feeds", exclude_from_nav: false)

  def render(assigns) do
    available = FeedNavigation.list_presets(current_user: current_user(assigns))

    preferred =
      Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], :my, assigns[:__context__])

    default = FeedNavigation.resolve_default(available, preferred)

    selected =
      case current_url(assigns) do
        url when is_binary(url) ->
          case URI.parse(url).path |> to_string() |> String.split("/", trim: true) do
            ["feed", slug | _] -> URI.decode(slug)
            ["feed"] -> if(current_user(assigns), do: "my", else: "local")
            _ -> nil
          end

        _ ->
          to_string(assigns[:selected_tab])
      end

    active? = Enum.any?(available, fn {slug, _} -> to_string(slug) == selected end)

    links = [
      %{
        id: "feeds",
        href: FeedNavigation.build_path(default),
        label: l("Feeds"),
        icon: "ph:rss-simple-fill",
        active?: active? and selected != "bookmarks"
      }
    ]

    links =
      if current_user(assigns) &&
           Enum.any?(available, fn {slug, _} -> to_string(slug) == "bookmarks" end) do
        links ++
          [
            %{
              id: "bookmarks",
              href: FeedNavigation.build_path(:bookmarks),
              label: l("Bookmarks"),
              icon: "ph:bookmark-simple-fill",
              active?: selected == "bookmarks"
            }
          ]
      else
        links
      end

    assigns
    |> assign(links: links)
    |> render_sface()
  end
end
