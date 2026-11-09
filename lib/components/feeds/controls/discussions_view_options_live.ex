defmodule Bonfire.UI.Social.DiscussionsViewOptionsLive do
  @moduledoc """
  Layout tabs for a discussions feed (the `:recent_discussions` preset, eg. a group's discussions tab), rendered by `Bonfire.UI.Social.FeedLive`: "Discussions" (one entry per thread) or "Latest updates" (every post), and the current tab's caret opens the sort order, like the current topic chip opens the topic's actions (`Bonfire.UI.Groups.GroupTopicsNavLive`). Each choice sends `set_filter` to the feed, for this visit only, like the thread's view options (`Bonfire.UI.Social.ThreadControlsLive`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_id, :string, required: true
  prop feed_filters, :any, default: nil

  @doc "Whether the feed lists one entry per thread, from `Bonfire.UI.Social.FeedLive.thread_grouped?/3` (`feed_filters` may not hold the preset's `dedup_by_thread`)"
  prop grouped, :boolean, default: true
  prop event_target, :any, default: nil

  @doc "The sorts offered, as `{sort_by, label}`: while grouped by thread, \"Recent replies\" (no `sort_by`, by latest activity) and \"Recent threads\" (`:date_created`, by each thread's start); without grouping `:date_created` lists posts, so it's \"Newest first\", and there's no latest-activity order, as the thread's linear mode drops it too."
  def sorts(grouped?, context) do
    if(grouped?,
      do: [{nil, l("Recent replies")}, {:date_created, l("Recent threads")}],
      else: [{:date_created, l("Newest first")}]
    ) ++
      [{:reply_count, l("Most replies")}] ++
      if extension_enabled?(:bonfire_ui_reactions, context),
        do: [
          {:boost_count, l("Most boosts")},
          {:like_count, l("Most liked")}
          # {:popularity_score, l("Trending")}
        ],
        else: []
  end

  @doc "Classes for a layout tab: full width, underlined in the primary colour when current."
  def tab_class(current?) do
    [
      "flex w-full items-center justify-center gap-1 border-b-2 py-3 text-sm font-bold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-base-content",
      if(current?,
        do: "border-primary text-base-content",
        else: "border-transparent text-subtle hover:text-base-content"
      )
    ]
  end

  @doc "Which sort is ticked: without grouping, no `sort_by` lists every post newest first."
  def selected_sort(grouped?, sort_by) do
    if not grouped? and is_nil(sort_by), do: :date_created, else: sort_by
  end
end
