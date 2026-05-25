defmodule Bonfire.UI.Social.WidgetRecentArticlesLive do
  @moduledoc """
  A widget displaying recent articles from followed users.

  Shows the most recent articles (posts with title + substantial content)
  from users the current user follows, without subject or action buttons.
  Results are cached per user and limit for 1 hour to avoid reloading on
  every LiveView render.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Cache

  prop limit, :integer, default: 5
  prop widget_title, :string, default: nil
  prop image_position, :atom, default: :side, values: [:side, :bottom]

  def load(current_user, limit \\ 5) do
    Cache.maybe_apply_cached(&do_load/2, [current_user, limit],
      cache_key: "widget_recent_articles:#{cache_user_id(current_user)}:#{limit}",
      expire: :timer.minutes(60)
    )
  end

  defp do_load(current_user, limit) do
    # Directly query articles using FeedActivities (simpler than feed_assigns_non_live)
    case Bonfire.Social.FeedActivities.feed(
           %{feed_name: :articles},
           current_user: current_user,
           paginate: %{limit: limit},
           preload: [:with_post_content, :with_subject, :with_media]
         ) do
      %{edges: edges} when is_list(edges) and edges != [] ->
        [articles: edges]

      _ ->
        [articles: []]
    end
  end

  defp cache_user_id(nil), do: "guest"
  defp cache_user_id(current_user), do: Bonfire.Common.Enums.id(current_user) || "guest"
end
