defmodule Bonfire.UI.Social.DefaultFeedSelectLive do
  @moduledoc "The \"Default feed\" select. Rendered by the feeds settings and the dashboard settings, inside their own form: both write `[Bonfire.UI.Social.FeedLive, :default_feed]` through `Bonfire.Common.Settings:set`."
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
      # pinned feeds first
      options:
        available
        |> Enum.sort_by(fn {_slug, preset} -> preset[:exclude_from_nav] != false end)
        |> Enum.map(fn {slug, preset} -> {slug, FeedNavigation.get_name(preset, slug)} end),
      default_feed: FeedNavigation.resolve_default(available, preferred)
    )
    |> render_sface()
  end
end
