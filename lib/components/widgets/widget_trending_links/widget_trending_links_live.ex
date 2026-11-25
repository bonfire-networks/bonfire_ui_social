# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.WidgetTrendingLinksLive do
  @moduledoc """
  A compact sidebar widget displaying trending links grouped by URL with engagement metrics.

  Shows the most boosted links with:
  - Link preview (title, description, thumbnail)
  - Total boost count across all shares
  - Number of unique users who shared the link

  The list is the one the feed loader caches for the viewer's circle (guests, or everyone signed in), as the other cached feeds do, then what the viewer may not see is left out. It follows the instance's setting for what widgets show (`[Bonfire.Social.Feeds, :widget_origin]`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget(l("Trending links"), width: :narrow, skeleton: :list)

  prop limit, :integer, default: 5
  prop widget_title, :string, default: nil
  prop showing_within, :atom, default: nil

  def load(current_user, limit \\ 5) do
    [
      links:
        Bonfire.Social.Media.trending_links(
          current_user: current_user,
          limit: limit,
          filters: Bonfire.Social.Feeds.widget_origin_filters()
        )
    ]
  end
end
