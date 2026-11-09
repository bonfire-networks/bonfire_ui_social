defmodule Bonfire.UI.Social.DiscussionsViewOptionsLive do
  @moduledoc """
  "View options" for a discussions feed (the `:recent_discussions` preset, eg. a group's discussions tab), rendered by `Bonfire.UI.Social.FeedLive`: one entry per thread or every post, and the sort order. Each choice sends `set_filter` to the feed, for this visit only, like the thread's view options (`Bonfire.UI.Social.ThreadControlsLive`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_id, :string, required: true
  prop feed_filters, :any, default: nil

  @doc "Whether the feed lists one entry per thread, from `Bonfire.UI.Social.FeedLive.thread_grouped?/3` (`feed_filters` may not hold the preset's `dedup_by_thread`)"
  prop grouped, :boolean, default: true
  prop event_target, :any, default: nil

  @doc "The sorts offered, as `{sort_by, label}`: \"Recently active\" (no `sort_by`) only while grouped by thread, as the thread's linear mode drops it too."
  def sorts(grouped?, context) do
    if(grouped?, do: [{nil, l("Recently active")}], else: []) ++
      [{:date_created, l("Newest first")}, {:reply_count, l("Most replies")}] ++
      if extension_enabled?(:bonfire_ui_reactions, context),
        do: [
          {:boost_count, l("Most boosts")},
          {:like_count, l("Most liked")}
          # {:popularity_score, l("Trending")}
        ],
        else: []
  end

  @doc "Which sort is ticked: without grouping, no `sort_by` lists every post newest first."
  def selected_sort(grouped?, sort_by) do
    if not grouped? and is_nil(sort_by), do: :date_created, else: sort_by
  end
end
