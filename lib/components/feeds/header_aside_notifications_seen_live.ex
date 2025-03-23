defmodule Bonfire.UI.Social.HeaderAsideNotificationsSeenLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop feed_name, :string, required: true
  prop feed_id, :string, required: true
  # prop tab, :string, default: nil
  # prop all_seen, :boolean, default: false
end
