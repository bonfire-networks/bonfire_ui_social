defmodule Bonfire.UI.Social.FeedsNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  declare_nav_component("Links to user's feeds", exclude_from_nav: false)

  def render(assigns) do
    presets =
      Bonfire.Social.Feeds.feed_presets_permitted(current_user: current_user(assigns))
      |> Enum.reject(fn {_slug, preset} ->
        preset[:exclude_from_nav] != false || preset[:parameterized]
      end)
      |> Enum.map(fn {slug, preset} ->
        # Map.put(preset, :id, slug)
        generate_link(
          preset[:name] || preset[:description] || slug,
          Bonfire.UI.Social.FeedsLive,
          Map.merge(preset, %{page: slug, href: "/feed/#{slug}"})
        )
      end)

    assigns
    |> assign(presets: presets)
    |> render_sface()
  end
end
