defmodule Bonfire.UI.Social.HeaderAsideFeedFiltersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # prop tab, :string, default: nil
  # prop all_seen, :boolean, default: false
  prop feed_name, :string, default: nil
end
