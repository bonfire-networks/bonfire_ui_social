defmodule Bonfire.UI.Social.WidgetDiscussionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_name, :any, default: :explore
  prop widget_title, :string, default: nil

  # 1 hours
  # @default_cache_ttl 1_000 * 60 * 60 * 1

  def feed(feed_name) do
    # NOTE: for now this only shows public threads so we can store one cache for all users
    Bonfire.Social.Feeds.LiveHandler.feed_assigns_non_live(
      feed_name,
      [
        hide_load_more: true,
        hide_tabs: true,
        no_header: true,
        hide_activities: "actions",
        infinite_pages: false,
        myself: nil,
        # TODO: better workarounds for using FeedLive as stateless
        streams: %{feed: nil}
      ],
      sort_by: :num_replies,
      # days
      time_limit: 10,
      limit: 4,
      cache_strategy: :guest_cache,
      preload: [:feed_by_subject, :feed_postload]
    )
  end

  # def list_users() do
  #   Cache.maybe_apply_cached(&do_list_users/1, [
  #     #  current_user: current_user_id, # TODO for respecting blocks/boundaries (but then can't have a single cache)
  #     paginate: [limit: 5]
  #   ], ttl: @default_cache_ttl)
  # end

  # defp do_list_users(opts) do
  #   Bonfire.Me.Users.list_paginated(opts)
  # end
end
