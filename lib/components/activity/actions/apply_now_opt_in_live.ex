defmodule Bonfire.UI.Social.ApplyNowOptInLive do
  @moduledoc """
  The `apply_now` checkbox, in the confirmation of a moderation action (lock, remove from the group, ban) taken in a group hosted on another instance.

  Such an action goes to the group, and takes effect here once the group applies it and sends it back. Ticked, it also takes effect here at once, and is undone if the group refuses it. Shown only to someone moderating the group from here (`Bonfire.Social.Moderations.moderating_elsewhere?/2`), and ticked by default as config says (`Moderations.apply_now?/1`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Social.Moderations

  @doc "The group the action is taken in"
  prop group, :any, default: nil

  def offered?(group, context),
    do: Moderations.moderating_elsewhere?(group, current_user(context))

  def checked?, do: Moderations.apply_now?([])

  def offer, do: l("Apply it here now")

  def what,
    do:
      l(
        "This group is hosted on another instance: this goes there, and takes effect here once the group applies it. Ticked, it also takes effect here straight away."
      )

  def risk, do: l("If the group refuses it, it is undone here.")
end
