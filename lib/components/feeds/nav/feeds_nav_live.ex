defmodule Bonfire.UI.Social.FeedsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  declare_nav_component("Links to user's feeds", exclude_from_nav: false)

  def render(assigns) do
    available = FeedNavigation.list_presets(current_user: current_user(assigns))
    preferred = Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], :my, assigns[:__context__])
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
          nil
      end

    active? = Enum.any?(available, fn {slug, _} -> to_string(slug) == selected end)

    presets =
      available
      |> Enum.filter(fn {_slug, preset} -> preset[:exclude_from_nav] == false end)
      |> Enum.map(fn {slug, preset} ->
        %{
          slug: to_string(slug),
          name: FeedNavigation.get_name(preset, slug),
          href: FeedNavigation.build_path(slug),
          active?: to_string(slug) == selected
        }
      end)

    assigns
    |> assign(
      presets: presets,
      active?: active?,
      default_href: FeedNavigation.build_path(default)
    )
    |> render_sface()
  end
end
