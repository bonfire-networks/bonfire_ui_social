defmodule Bonfire.UI.Social.DefaultFeedSelectLive do
  @moduledoc "The \"Default feed\" select, rendered by the feeds settings inside their own form: it writes `[Bonfire.UI.Social.FeedLive, :default_feed]` through `Bonfire.Common.Settings:set`."
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  @doc "Presets already loaded with `FeedNavigation.list_presets/1`, if any."
  prop presets, :list, default: nil

  prop id, :string, default: "default-feed-select"
  prop scope, :any, default: nil

  data options, :list, default: []
  data default_feed, :any, default: nil

  def render(assigns) do
    available =
      assigns.presets || FeedNavigation.list_presets(current_user: current_user(assigns))

    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns.scope, assigns[:__context__])
    preferred = Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], :my, scoped)

    assigns
    |> assign(
      options: FeedNavigation.select_options(available),
      default_feed: FeedNavigation.resolve_default(available, preferred)
    )
    |> render_sface()
  end
end
