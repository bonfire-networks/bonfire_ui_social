defmodule Bonfire.UI.Social.ThreadMarkSeenLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop thread_id, :string, required: true
  # prop tab, :string, default: nil
  # prop all_seen, :boolean, default: false
end
