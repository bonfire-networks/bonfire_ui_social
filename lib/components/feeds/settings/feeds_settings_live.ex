defmodule Bonfire.UI.Social.FeedsSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop scope, :atom, default: nil
  data presets, :list, default: []

  @doc "Renders feed defaults and permitted built-in and custom preset settings."
  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      available = FeedNavigation.list_presets(current_user: current_user(assigns))
      preferred = Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], :my, scoped)

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
        default_feed: FeedNavigation.resolve_default(available, preferred),
        default_feed_form: Phoenix.Component.to_form(%{})
      )
      |> render_sface()
    end
  end
end
