defmodule Bonfire.UI.Social.WidgetTimelinesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string
  prop page, :string

  declare_widget("Links to main social feeds")
end
