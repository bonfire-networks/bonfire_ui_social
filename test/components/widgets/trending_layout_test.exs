defmodule Bonfire.UI.Social.TrendingDiscussionsLayoutTest do
  @moduledoc "Top discussions takes its layout from the shared `Bonfire.UI.Common.WidgetLayoutLive` setting, stored under `[WidgetTrendingDiscussionsLive, :layout]` as \"carousel\" or \"stacked\"."
  use Bonfire.UI.Social.ConnCase, async: false

  alias Bonfire.UI.Common.WidgetLayoutLive
  alias Bonfire.UI.Social.WidgetTrendingDiscussionsLive

  @key [:bonfire_ui_social, WidgetTrendingDiscussionsLive, :layout]

  test "a carousel unless one under the other was chosen" do
    assert WidgetTrendingDiscussionsLive.layout(%{}) == "carousel"

    Process.put(@key, "stacked")
    assert WidgetTrendingDiscussionsLive.layout(%{}) == "stacked"
  end

  test "edit mode's chip names the layout chosen" do
    Process.put(@key, "stacked")

    assert WidgetLayoutLive.current_label(%{}, nil, WidgetTrendingDiscussionsLive) ==
             "One under the other"
  end
end
