defmodule Bonfire.UI.Social.WidgetFeedSelectLive do
  @moduledoc "The \"Feed shown on the dashboard\" select, rendered by the dashboard settings inside their own form: it writes `[Bonfire.UI.Social.WidgetFeedLive, :feed]` through `Bonfire.Common.Settings:set`, apart from the default feed."
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  @doc "Presets already loaded with `FeedNavigation.list_presets/1`, if any."
  prop presets, :list, default: nil

  prop id, :string, default: "widget-feed-select"
  prop scope, :any, default: nil

  data options, :list, default: []
  data feed, :any, default: nil

  def render(assigns) do
    {options, feed} = options_and_value(assigns.presets, assigns.scope, assigns)

    assigns
    |> assign(options: options, feed: feed)
    |> render_sface()
  end

  @doc "The name of the feed the widget shows, for edit mode's tile."
  def current_label(context) do
    {options, feed} = options_and_value(nil, nil, context)
    Enum.find_value(options, fn {slug, name} -> to_string(slug) == to_string(feed) && name end)
  end

  defp options_and_value(presets, scope, context) do
    available = presets || FeedNavigation.list_presets(current_user: current_user(context))
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(scope, context[:__context__] || context)

    {FeedNavigation.select_options(available), FeedNavigation.widget_feed(available, scoped)}
  end
end
