defmodule Bonfire.UI.Social.NotificationPreferencesLive do
  @moduledoc "UI-only notification preferences. Native controls are intentionally disconnected from settings and delivery."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Activity labels for the notification preferences design preview."
  def activity_types do
    [
      {"mention", l("Mentions")},
      {"reply", l("Replies")},
      {"like", l("Likes")},
      {"boost", l("Boosts")},
      {"follow", l("New followers")},
      {"request", l("Follow requests")},
      {"quote", l("Quotes")},
      {"other", l("Other activity")}
    ]
  end

  @doc "Audience options shown as a design preview, not implemented policies."
  def audience_types do
    [
      {"not_followed", l("People you don’t follow"), l("Accounts outside the people you follow.")},
      {"not_following", l("People not following you"), l("Accounts that don’t follow you.")},
      {"new", l("New accounts"), l("Accounts created in the past 30 days.")},
      {"private", l("Unsolicited private mentions"), l("Private mentions outside an existing conversation.")},
      {"moderated", l("Moderated accounts"), l("Accounts limited by instance moderators.")},
      {"bots", l("Bots"), l("Accounts marked as automated.")}
    ]
  end
end
