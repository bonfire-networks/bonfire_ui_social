defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsLive do
  @moduledoc """
  Widget rendering the most replied discussions of the last day
  (`:trending_discussions` preset), as a carousel. Each card is a standard `ActivityLive`
  whose actions are swapped for `DiscussionPreviewActionsLive` (reply counter
  + participants facepile) via the `custom_actions` prop.
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
       l("Top discussions have been reset.") <>
         " " <> l("You need to reload to see updates, if any.")
     )}
  end

  @doc """
  Card width for `visible_items` cards per row, `:peek` for one full card with the first 1rem of the next showing, or 70% (as the Spotlight carousel sizes them).

      iex> Bonfire.UI.Social.WidgetTrendingDiscussionsLive.carousel_item_width(nil)
      "70%"

      iex> Bonfire.UI.Social.WidgetTrendingDiscussionsLive.carousel_item_width(2)
      "calc((100% - 0.75rem) / 2)"

      iex> Bonfire.UI.Social.WidgetTrendingDiscussionsLive.carousel_item_width(:peek)
      "calc(100% - 1.75rem)"
  """
  # 0.75rem gap + 1rem of the next card
  def carousel_item_width(:peek), do: "calc(100% - 1.75rem)"

  def carousel_item_width(visible_items) when is_number(visible_items) and visible_items > 0,
    do: "calc((100% - #{(visible_items - 1) * 0.75}rem) / #{visible_items})"

  def carousel_item_width(_), do: "70%"

  defp reset_limit(%{"limit" => limit}) when is_binary(limit), do: String.to_integer(limit)
  defp reset_limit(_), do: 3
end
