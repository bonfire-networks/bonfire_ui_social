# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.WidgetFeedsLive do
  @moduledoc """
  A sidebar widget that lists the current user's permitted feed presets as
  quick-jump links. Mirrors the data pipeline used by
  `Bonfire.UI.Social.FeedsNavLive` so feed visibility stays consistent with the
  left nav.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Modularity.DeclareHelpers

  prop widget_title, :string, default: nil
  prop page, :any, default: nil
  prop selected_tab, :any, default: nil
  prop showing_within, :atom, default: :sidebar

  def render(assigns) do
    selected = normalize_tab(assigns[:selected_tab])

    presets =
      [current_user: current_user(assigns)]
      |> Bonfire.Social.Feeds.feed_presets_permitted()
      |> Enum.flat_map(&preset_to_link(&1, selected))

    assigns
    |> assign(presets: presets)
    |> render_sface()
  end

  defp normalize_tab(nil), do: nil
  defp normalize_tab(value), do: value |> to_string() |> String.downcase()

  defp preset_to_link({slug, preset}, selected) do
    if show_in_widget?(preset) do
      selected? = selected != nil and selected == String.downcase(to_string(slug))

      link =
        DeclareHelpers.generate_link(
          preset[:name] || preset[:description] || slug,
          Bonfire.UI.Social.FeedsLive,
          Map.merge(preset, %{
            page: slug,
            href: "/feed/#{slug}",
            extension: :bonfire_social,
            selected?: selected?
          })
        )

      [link]
    else
      []
    end
  end

  defp show_in_widget?(preset) do
    preset[:exclude_from_nav] == false and
      preset[:icon] not in [nil, ""] and
      preset[:parameterized] in [nil, %{subjects: [:me]}]
  end
end
