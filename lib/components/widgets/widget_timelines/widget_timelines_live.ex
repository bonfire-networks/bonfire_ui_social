defmodule Bonfire.UI.Social.WidgetTimelinesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil
  prop page, :string, default: nil

  # declare_widget("Links to main social feeds")
  declare_nav_component("Links to main social feeds")
end
