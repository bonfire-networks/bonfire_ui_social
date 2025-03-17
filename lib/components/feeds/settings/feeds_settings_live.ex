defmodule Bonfire.UI.Social.FeedsSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any
  prop scope, :atom, default: nil
  prop presets, :list, default: []

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      presets =
        Bonfire.Social.Feeds.feed_presets_permitted(current_user: current_user(assigns))
        |> Enum.reject(fn {_slug, preset} ->
          preset[:parameterized]
        end)
        |> Enum.map(fn {id, preset} ->
          Map.put(preset, :id, id)
        end)

      assigns
      |> assign(scoped: scoped)
      |> assign(page_title: l("Feeds options"))
      |> assign(presets: presets)
      |> render_sface()
    end
  end

  def handle_event("edit_preset", %{"id" => preset_id}, socket) do
    # TODO: Implement edit preset functionality
    {:noreply, socket}
  end

  def handle_event("delete_preset", %{"id" => preset_id}, socket) do
    # TODO: Implement delete preset functionality
    {:noreply, socket}
  end
end
