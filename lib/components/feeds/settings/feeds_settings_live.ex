defmodule Bonfire.UI.Social.FeedsSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop scope, :atom, default: nil
  data presets, :list, default: []
  data available, :list, default: []

  @doc "Renders feed defaults and permitted built-in and custom preset settings."
  def render(assigns) do
    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      # loaded once, for the default feed select and the list of pins
      available = FeedNavigation.list_presets(current_user: current_user(assigns))

      presets =
        available
        |> Enum.map(fn {id, preset} ->
          Map.put(preset, :id, id)
        end)
        |> Enum.sort_by(fn preset ->
          preset[:exclude_from_nav] != false
        end)

      assigns
      |> assign(
        presets: presets,
        available: available,
        default_feed_form: Phoenix.Component.to_form(%{})
      )
      |> render_sface()
    end
  end
end
