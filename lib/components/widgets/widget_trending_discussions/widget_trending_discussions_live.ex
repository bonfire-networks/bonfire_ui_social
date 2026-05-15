defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsLive do
  @moduledoc """
  Widget rendering the most replied discussions of the last 7 days
  (`:trending_discussions` preset). Each row uses `DiscussionPreviewLive`.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop limit, :integer, default: 3
  prop widget_title, :string, default: nil

  def load(current_user, limit) do
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
end
