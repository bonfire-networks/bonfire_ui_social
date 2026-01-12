# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.WidgetTrendingLinksLive do
  @moduledoc """
  A compact sidebar widget displaying trending links grouped by URL with engagement metrics.

  Shows the most boosted links with:
  - Link preview (title, description, thumbnail)
  - Total boost count across all shares
  - Number of unique users who shared the link

  Data is cached globally (1 hour TTL) since trending links are public content.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop limit, :integer, default: 5
  prop widget_title, :string, default: nil
  prop showing_within, :atom, default: nil

  def load(_limit \\ 5) do
    # Only return cached data - don't trigger slow queries from UI
    # Cache is warmed by TrendingLinksCacheWorker Oban cron job
    # Note: We don't pass limit option to match the cache key used by warm_cache()
    # The default limit (5) is already applied in list_trending_paginated
    [links: Bonfire.Social.Media.cached_trending_links() || []]
  end
end
