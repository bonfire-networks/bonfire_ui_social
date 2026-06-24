defmodule Bonfire.UI.Social.WidgetSuggestedProfilesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  @doc """
  Lists suggested profiles (curated by admins) — delegates to the shared, cached
  `Bonfire.Boundaries.Circles.list_suggested_profiles/0` so the widget and the Masto
  `/api/v2/suggestions` endpoint share one cache.
  """
  def list_suggested_profiles, do: Bonfire.Boundaries.Circles.list_suggested_profiles()

  @doc "Busts the cache so a reload reflects edits to the circle (recomputed lazily on next read)."
  def handle_event("reset_suggested_profiles", _params, socket) do
    Bonfire.Boundaries.Circles.list_suggested_profiles(cache: :reset)

    {:noreply,
     assign_flash(
       socket,
       :info,
       l("Suggested profiles have been reset.") <>
         l(" You need to reload to see updates, if any.")
     )}
  end
end
