defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.UI.Common.Web, :stateless_component

  # Source the verb families from the same compile-env keys ActivityLive uses,
  # so operator overrides in :verb_families stay consistent across the activity UI.
  @reply_verbs Application.compile_env(:bonfire, [:verb_families, :reply]) || ["Respond"]
  @create_verbs Application.compile_env(:bonfire, [:verb_families, :create]) || ["Write", "Send"]
  @react_verbs (Application.compile_env(:bonfire, [:verb_families, :react]) || []) ++ ["React"]

  prop activity_id, :any, default: nil
  prop object, :any, default: nil
  prop object_id, :any, default: nil
  prop peered, :any, default: nil
  # prop reply_to_id, :any, default: nil
  # prop profile, :any, default: nil
  # prop character, :any, default: nil
  prop verb, :string, default: nil
  prop verb_display, :string, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil
  prop subject_id, :any, default: nil
  # prop subject_user, :any, default: nil
  prop subjects_more, :list, default: []
  prop profile_name, :string, default: nil
  prop character_username, :string, default: nil
  prop path, :string, default: nil
  prop profile_media, :string, default: nil
  prop profile_id, :string, default: nil
  prop parent_id, :any, default: nil
  prop tagged, :any, default: nil
  prop emoji, :any, default: nil

  # def render(assigns),
  #   do: Bonfire.UI.Social.Activity.SubjectLive.prepare(assigns, __MODULE__) |> render_sface()

  def notification_icon(verb) when verb in @reply_verbs, do: "ph:chat-circle-duotone"
  def notification_icon(verb) when verb in @create_verbs, do: "ph:at-duotone"
  def notification_icon("Boost"), do: "ph:arrows-counter-clockwise-duotone"
  def notification_icon(verb) when verb in @react_verbs, do: "ph:fire-fill"

  def notification_icon(verb) when verb in ["Follow", "Request to Follow"],
    do: "ph:user-plus-duotone"

  def notification_icon("Request to Quote"), do: "ph:quotes-duotone"
  def notification_icon("Pin"), do: "ph:push-pin-duotone"
  def notification_icon("Flag"), do: "ph:flag-duotone"
  def notification_icon(_), do: nil

  # Semantic color groups: interactive (replies/mentions), social-graph
  # (follow/quote requests), reactions (likes/boosts/pins), moderation (flag).
  def notification_icon_color(verb) when verb in @reply_verbs, do: "text-primary"
  def notification_icon_color(verb) when verb in @create_verbs, do: "text-primary"

  def notification_icon_color(verb)
      when verb in ["Follow", "Request to Follow", "Request to Quote"],
      do: "text-secondary"

  def notification_icon_color(verb) when verb in @react_verbs, do: "text-warning"
  def notification_icon_color("Boost"), do: "text-warning"
  def notification_icon_color("Pin"), do: "text-warning"
  def notification_icon_color("Flag"), do: "text-error"
  def notification_icon_color(_), do: "text-base-content/70"

  def notification_aggregate?(verb) when verb in @react_verbs, do: true
  def notification_aggregate?("Boost"), do: true
  def notification_aggregate?(_), do: false
end
