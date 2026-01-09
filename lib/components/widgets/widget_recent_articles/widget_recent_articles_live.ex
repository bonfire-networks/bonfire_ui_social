defmodule Bonfire.UI.Social.WidgetRecentArticlesLive do
  @moduledoc """
  A widget displaying recent articles from followed users.

  Shows the most recent articles (posts with title + substantial content)
  from users the current user follows, without subject or action buttons.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop limit, :integer, default: 5
  prop widget_title, :string, default: nil

  def load(current_user, limit \\ 5) do
    # Directly query articles using FeedActivities (simpler than feed_assigns_non_live)
    # Note: :with_post_content is NOT needed here because the :articles feed filter
    # already joins and preloads post_content for filtering by title/body length
    case Bonfire.Social.FeedActivities.feed(
           %{feed_name: :articles},
           current_user: current_user,
           paginate: %{limit: limit},
           preload: [:with_object, :with_subject, :with_media]
         ) do
      %{edges: edges} when is_list(edges) and edges != [] ->
        [articles: edges]

      _ ->
        [articles: []]
    end
  end
end
