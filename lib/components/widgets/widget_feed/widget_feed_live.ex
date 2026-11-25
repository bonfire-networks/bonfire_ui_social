defmodule Bonfire.UI.Social.WidgetFeedLive do
  @moduledoc """
  A feed as a widget, for places like the dashboard and the guest homepage. It picks its feed and renders `Bonfire.UI.Social.FeedLive`, which loads it: for guests right away (on the static render), for signed-in people once connected.

  - Guests get the local feed, or the curated one when the instance turned that on.
  - Signed-in people get the feed chosen for the widget (`[Bonfire.UI.Social.WidgetFeedLive, :feed]`, apart from their default feed, which the Feeds link opens), or `requested_feed` (eg. the dashboard's `?feed=` tabs) when it's one they may see.
  """
  # stateless: `FeedLive` inside it holds the feed's state (items, paging, live updates)
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Settings

  declare_widget(l("Feed"),
    id: :feed,
    width: :wide,
    # which feed it shows, chosen in edit mode and in the dashboard settings
    settings: Bonfire.UI.Social.WidgetFeedSelectLive,
    skeleton: :feed
  )

  @doc "A feed slug asked for, eg. from the dashboard's `?feed=` tabs. Only used when it's one of the viewer's feeds."
  prop requested_feed, :string, default: nil
  @doc "Shows the viewer's feeds as tabs, each linking to this function's result for its slug."
  prop feed_tabs_path, :any, default: nil

  @doc "Whether a place shows the feed when nobody has chosen, beyond its flavour's list: on the dashboard, for people who used the old feed-only mode (`[DashboardLive, :default_feed]`), which this replaces."
  def included_by_default?({Bonfire.Web.Views.DashboardLive, _}, current_user)
      when not is_nil(current_user) do
    Settings.get([Bonfire.Web.Views.DashboardLive, :default_feed], false,
      current_user: current_user
    ) in [:my, true]
  end

  def included_by_default?(_place, _current_user), do: false

  @doc "The props for `FeedLive`, as a keyword list (with its `feed_component_id`), or `nil` when there's no feed to show. Takes the render context (or a socket)."
  def feed_props(context, requested \\ nil) do
    case current_user(context) do
      nil -> guest_feed_props(context)
      current_user -> member_feed_props(context, current_user, requested)
    end
  end

  defp guest_feed_props(context) do
    feed_name =
      if module_enabled?(Bonfire.Social.Pins, context) and
           Settings.get([Bonfire.UI.Social.FeedsLive, :curated], false, :instance) do
        :curated
      else
        :local
      end

    {feed_name, %{}}
    |> Bonfire.Social.Feeds.LiveHandler.feed_default_assigns(context)
    |> Keyword.merge(time_limit: 30, top_page: "Explore", current_url: "/feed/")
  end

  defp member_feed_props(context, current_user, requested) do
    # loaded once, also for the tabs
    presets =
      maybe_apply(Bonfire.UI.Social.FeedNavigation, :list_presets, [[current_user: current_user]],
        fallback_return: []
      )

    case Bonfire.Social.Feeds.LiveHandler.feed_default_assigns(
           feed_name(presets, current_user, requested) |> with_filters(),
           context
         ) do
      [_ | _] = feed ->
        # always start from the newest activities, not the preset's saved reading position
        feed
        |> Keyword.put(:disable_marker, true)
        |> Keyword.put(:nav_presets, presets)

      _ ->
        nil
    end
  end

  # the requested feed if permitted, else the widget's own feed
  defp feed_name(presets, current_user, requested) do
    # matched against permitted slugs: never an atom from the URL
    requested =
      requested &&
        Enum.find_value(presets, fn {slug, _} -> to_string(slug) == requested && slug end)

    requested ||
      maybe_apply(
        Bonfire.UI.Social.FeedNavigation,
        :widget_feed,
        [presets, [current_user: current_user]],
        fallback_return: nil
      ) || :default
  end

  # string (custom) feed names only resolve as presets with filters, as on `/feed/<name>`
  defp with_filters(name) when is_binary(name), do: {name, %{}}
  defp with_filters(name), do: name
end
