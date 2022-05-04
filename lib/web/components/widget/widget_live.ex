defmodule Bonfire.UI.Social.WidgetLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string

  @doc "A call to action, usually redirect to the specific page"
  slot action

  @doc "The main content of the widget"
  slot default, required: true

end
