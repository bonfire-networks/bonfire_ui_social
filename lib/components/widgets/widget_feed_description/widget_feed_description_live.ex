defmodule Bonfire.UI.Social.WidgetFeedDescriptionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_name, :any, default: nil

  def preset(nil, _context), do: nil

  def preset(feed_name, context) do
    case Bonfire.Social.Feeds.feed_preset_if_permitted(feed_name, context) do
      {:ok, preset} -> preset
      _ -> nil
    end
  end
end
