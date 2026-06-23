defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsLive do
  @moduledoc """
  Widget rendering the most replied discussions of the last 7 days
  (`:trending_discussions` preset). Each row uses `DiscussionPreviewLive`.
  Results are cached per user and limit for 1 hour to avoid reloading on
  every LiveView render.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop limit, :integer, default: 3
  prop widget_title, :string, default: nil

  @doc "Delegates to the cached `Bonfire.Social.Threads.list_trending/3`."
  def load(current_user, limit), do: Bonfire.Social.Threads.list_trending(current_user, limit)

  @doc "Busts the top-discussions cache for the current viewer (recomputed lazily on next read)."
  def handle_event("reset_trending_discussions", params, socket) do
    Bonfire.Social.Threads.list_trending(current_user(socket), reset_limit(params), cache: :reset)

    {:noreply,
     assign_flash(
       socket,
       :info,
       l("Top discussions have been reset.") <> l(" You need to reload to see updates, if any.")
     )}
  end

  defp reset_limit(%{"limit" => limit}) when is_binary(limit), do: String.to_integer(limit)
  defp reset_limit(_), do: 3
end
