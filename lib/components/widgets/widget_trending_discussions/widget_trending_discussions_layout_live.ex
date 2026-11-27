defmodule Bonfire.UI.Social.WidgetTrendingDiscussionsLayoutLive do
  @moduledoc "The Top discussions widget's layout setting: carousel (the default) or stacked."
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, default: "widget-trending-discussions-layout"
  prop scope, :any, default: nil

  data options, :list, default: []
  data layout, :string, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns.scope, assigns[:__context__])

    assigns
    |> assign(
      options: options(),
      layout: Bonfire.UI.Social.WidgetTrendingDiscussionsLive.layout(scoped)
    )
    |> render_sface()
  end

  @doc "The name of the layout the widget uses, for edit mode's tile: the viewer's, or with `:instance` the instance's default."
  def current_label(context, scope) do
    # scoped as `render/1` is, and as `Bonfire.UI.Social.WidgetFeedSelectLive.current_label/2`
    layout =
      Bonfire.UI.Social.WidgetTrendingDiscussionsLive.layout(
        Bonfire.Common.Settings.LiveHandler.scoped(scope, context[:__context__] || context)
      )

    Enum.find_value(options(), fn {value, name} -> value == layout && name end)
  end

  defp options, do: [{"carousel", l("Carousel")}, {"stacked", l("One under the other")}]
end
