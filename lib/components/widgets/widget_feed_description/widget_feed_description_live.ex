defmodule Bonfire.UI.Social.WidgetFeedDescriptionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedNavigation

  prop feed_name, :any, default: nil

  @doc "Show as a titled sidebar widget (for guests, who have no header toggle) rather than inside the feed tabs' details panel."
  prop boxed, :boolean, default: false

  # shared by the popover's action rows (default, pin switch, settings link)
  @row_class "flex h-10 items-center gap-3 rounded-[10px] px-3 text-left text-sm text-base-content transition-colors duration-150 ease-out hover:bg-base-200 disabled:cursor-default disabled:hover:bg-transparent motion-reduce:transition-none focus-visible:outline focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary"

  @doc "Renders a permitted feed's description with the user's default, pin and settings actions."
  def render(assigns) do
    preset = preset(assigns.feed_name, assigns.__context__)
    user = current_user(assigns)
    available = if user, do: FeedNavigation.list_presets(current_user: user), else: []

    preferred =
      Settings.get([Bonfire.UI.Social.FeedLive, :default_feed], :my, assigns.__context__)

    default = FeedNavigation.resolve_default(available, preferred)
    default? = not is_nil(default) and to_string(default) == to_string(assigns.feed_name)

    assigns
    |> assign(
      preset: preset,
      row_class: @row_class,
      can_set_default?:
        Enum.any?(available, fn {id, _} -> to_string(id) == to_string(assigns.feed_name) end),
      default?: default?,
      default_label: if(default?, do: l("Default feed"), else: l("Set as default feed")),
      pinned: e(preset, :exclude_from_nav, nil) == false
    )
    |> render_sface()
  end

  @doc "Looks up a feed's localized preset with its normal permission checks."
  def preset(nil, _context), do: nil

  def preset(feed_name, context) do
    case Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, context) do
      {:ok, preset} -> preset
      _ -> nil
    end
  end
end
