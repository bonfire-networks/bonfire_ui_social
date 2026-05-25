defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsLive do
  @moduledoc """
  Widget rendering the most replied discussions of the last 7 days
  (`:trending_discussions` preset). Each row uses `DiscussionPreviewLive`.
  Results are cached per user and limit for 1 hour to avoid reloading on
  every LiveView render.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Cache

  prop limit, :integer, default: 3
  prop widget_title, :string, default: nil

  def load(current_user, limit) do
    Cache.maybe_apply_cached(&do_load/2, [current_user, limit],
      cache_key: "widget_trending_discussions:#{cache_user_id(current_user)}:#{limit}",
      expire: :timer.minutes(60)
    )
  end

  defp do_load(current_user, limit) do
    case Bonfire.Social.FeedLoader.feed(
           :trending_discussions,
           current_user: current_user,
           paginate: %{limit: limit},
           preload: [:feed]
         ) do
      %{edges: edges} when is_list(edges) -> edges
      _ -> []
    end
  end

  defp cache_user_id(nil), do: "guest"
  defp cache_user_id(current_user), do: Bonfire.Common.Enums.id(current_user) || "guest"
end
