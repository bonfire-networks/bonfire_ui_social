defmodule Bonfire.UI.Social.NotificationFiltersLive do
  @moduledoc "Notification category controls for the UI preview; selection does not query the feed."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Notification categories and their icons for the filter bar."
  def categories do
    [
      {"all", l("All notifications"), nil},
      {"mention", l("Mentions"), "ph:at"},
      {"reply", l("Replies"), "ph:arrow-bend-up-left"},
      {"like", l("Likes"), "ph:heart"},
      {"boost", l("Boosts"), "ph:rocket-launch"},
      {"follow", l("New followers"), "ph:user-plus"},
      {"request", l("Follow requests"), "ph:user-check"},
      {"quote", l("Quotes"), "ph:quotes"}
    ]
  end
end
