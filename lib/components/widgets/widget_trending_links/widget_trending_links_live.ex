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

  @doc "Where the link comes from: the site's name when it gives one, else its host (some sites give a URL as their name)."
  def source(%{} = media) do
    case Bonfire.UI.Social.Activity.MediaLive.provider(media) do
      "http" <> _ -> URIs.base_domain(media.path)
      provider when is_binary(provider) and provider != "" -> provider
      _ -> URIs.base_domain(media.path)
    end
  end

  @doc "How many times the link was shared into feeds: the posts that include it plus their boosts."
  def shares(%{} = media) do
    Bonfire.UI.Social.MediaActionsLive.count(media, :object_count) +
      Bonfire.UI.Social.MediaActionsLive.count(media, :boost_count)
  end

  @doc "What the shares count is made of, for its tooltip: the posts (same string as `MediaActionsLive`), then the boosts when there are any."
  def shares_title(%{} = media) do
    posts = Bonfire.UI.Social.MediaActionsLive.count(media, :object_count)
    boosts = Bonfire.UI.Social.MediaActionsLive.count(media, :boost_count)
    used = lp("Used in %{count} post", "Used in %{count} posts", posts, count: posts)

    if boosts > 0,
      do:
        used <>
          ", " <> lp("boosted %{count} time", "boosted %{count} times", boosts, count: boosts),
      else: used
  end
end
