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
    available =
      assigns.presets || FeedNavigation.list_presets(current_user: current_user(assigns))

    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns.scope, assigns[:__context__])

    assigns
    |> assign(
      options: FeedNavigation.select_options(available),
      feed: FeedNavigation.widget_feed(available, scoped)
    )
    |> render_sface()
  end
end
