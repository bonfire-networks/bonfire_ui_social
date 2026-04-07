defmodule Bonfire.UI.Social.WidgetParticipantsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop participants, :list, default: []
  prop widget_title, :string, default: nil
end
