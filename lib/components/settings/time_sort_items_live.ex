defmodule Bonfire.UI.Social.Settings.TimeSortItemsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop title, :string
  prop scope, :any, default: nil
  prop feed_name, :any, default: nil
  prop event_name, :any, default: nil
  prop event_target, :any, default: nil
  prop compact, :boolean, default: false
  prop time_limit, :integer, default: nil
end
