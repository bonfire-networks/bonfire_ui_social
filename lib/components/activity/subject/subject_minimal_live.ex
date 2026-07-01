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

  def notification_icon(verb) when verb in @reply_verbs, do: "ph:chat-circle-fill"
  def notification_icon(verb) when verb in @create_verbs, do: "ph:at-fill"
  def notification_icon("Boost"), do: "ph:arrows-counter-clockwise-fill"
  def notification_icon(verb) when verb in @react_verbs, do: "ph:fire-fill"

  def notification_icon(verb) when verb in ["Follow", "Request to Follow"],
    do: "ph:user-plus-fill"

  def notification_icon("Request to Quote"), do: "ph:quotes-fill"
  def notification_icon("Pin"), do: "ph:push-pin-fill"
  def notification_icon("Flag"), do: "ph:flag-fill"
  def notification_icon("Vote"), do: "ph:chart-bar-fill"
  def notification_icon(_), do: nil

  def notification_aggregate?(verb) when verb in @react_verbs, do: true
  def notification_aggregate?("Boost"), do: true
  def notification_aggregate?("Vote"), do: true
  def notification_aggregate?(_), do: false

  # Shared layout classes so the `:notifications` header and every feed
  # reason-line (boosted/liked/pinned/flagged/…) render identically: a full-bleed
  # hairline divider pulled to the card edges (`-mx-card`/`px-card`) + an 18px
  # primary verb icon. Kept here (a scanned `*_live.ex`) so the tokens are picked
  # up by Tailwind. See the `NotificationCard` styleguide for the visual contract.
  @doc false
  def subject_minimal_line_class,
    do:
      "flex items-start gap-half -mx-card px-card -mt-1.5 pb-content mb-content border-b-hair border-secondary"

  @doc false
  def subject_minimal_icon_box_class,
    do: "flex-shrink-0 w-[18px] flex items-start justify-center mt-px"

  @doc """
  The notification verb phrase ("liked your activity", "voted on your poll", …).

  Returns `nil` for unhandled verbs (and for verbs whose object precondition
  isn't met, e.g. a `Schedule` with no due date) so the caller falls back to the
  raw `verb_display`. `current_user_id` is passed in (already resolved from the
  context) so the relationship-aware phrases can say "you".
  """
  def notification_phrase(verb, _object_id, _current_user_id, _tagged, _object)
      when verb in ["Reply", "Respond", "Annotate"],
      do: l("replied to you")

  def notification_phrase(verb, _object_id, _current_user_id, tagged, _object)
      when verb in ["Create", "Write"] and tagged not in [nil, []],
      do: l("mentioned you")

  def notification_phrase("React", _, _, _, _), do: l("reacted to your activity")
  def notification_phrase("Like", _, _, _, _), do: l("liked your activity")
  def notification_phrase("Boost", _, _, _, _), do: l("boosted your activity")
  def notification_phrase("Vote", _, _, _, _), do: l("voted on your poll")

  def notification_phrase("Follow", object_id, current_user_id, _, _),
    do: if(object_id == current_user_id, do: l("followed you"), else: l("followed"))

  def notification_phrase("Request to Follow", object_id, current_user_id, _, _),
    do:
      if(object_id == current_user_id,
        do: l("requested to follow you"),
        else: l("requested to follow")
      )

  def notification_phrase("Request to Quote", _, _, _, _), do: l("wants to quote your post")
  def notification_phrase("Pin", _, _, _, _), do: l("pinned")

  def notification_phrase(verb, _, _, _, object)
      when verb in ["Schedule", "Label", "Assign", "Appoint"],
      do: object_state_phrase(verb, object)

  def notification_phrase(_, _, _, _, _), do: nil

  @doc """
  Object-state phrases — `Schedule` (due date), `Label` (finished?),
  `Assign`/`Appoint` (provider). Third-person-neutral (no "you"/"your"), so the
  feed reason-line fallback can share them with the notifications header without
  leaking notification framing. Returns `nil` when the precondition isn't met
  (e.g. a `Schedule` with no due date) → the caller shows the raw `verb_display`.
  """
  def object_state_phrase("Schedule", object) do
    case e(object, :due, nil) do
      nil -> nil
      due -> l("scheduled for %{date}", date: DatesTimes.date_from_now(due))
    end
  end

  def object_state_phrase("Label", object) do
    case e(object, :finished, nil) do
      true -> l("completed")
      false -> l("re-opened")
      _ -> nil
    end
  end

  def object_state_phrase(verb, object) when verb in ["Assign", "Appoint"] do
    case e(object, :provider, nil) do
      nil ->
        nil

      provider ->
        l("assigned to %{name}",
          name: e(provider, :profile, :name, nil) || e(provider, :character, :username, nil)
        )
    end
  end

  def object_state_phrase(_, _), do: nil
end
