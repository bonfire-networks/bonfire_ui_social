defmodule Bonfire.UI.Social.HiddenAudiencesLive do
  @moduledoc """
  The "Hide notifications and messages from" switches: one per audience in `Bonfire.Social.Notifications.audiences/0`, each hiding that audience from the notifications feed, the messages list, push and email.

  One component, shown by the notification preferences panel, beside the messages list, and in Privacy & Safety settings, so the same switches read the same everywhere.
  """
  use Bonfire.UI.Common.Web, :stateless_component
end
