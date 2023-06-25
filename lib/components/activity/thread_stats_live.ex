defmodule Bonfire.UI.Social.Activity.ThreadStatsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text

  # prop object, :any
  # prop activity, :any, default: nil
  prop is_remote, :boolean, default: false


end
