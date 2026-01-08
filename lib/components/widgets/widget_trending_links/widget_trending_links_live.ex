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

  def load(limit \\ 5) do
    [links: Bonfire.Social.Media.trending_links(limit: limit)]
  end
end
