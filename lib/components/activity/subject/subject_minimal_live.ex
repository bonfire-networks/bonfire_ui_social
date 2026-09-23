defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  @moduledoc """
  The subject line of a notification row.

  Everything it renders per kind is declared rather than written here: the icon, the sentence, and whether several collapse into one row all come from the notification categories and the verb registry, read through `Bonfire.Social.Notifications`, keyed by what `Bonfire.Social.Activities.experienced_as/2` answered. So a kind reads the same in a row, a chip, a push and a digest, and adding one is a config entry.

  What stays here is wording that depends on an object's own state (a due date, whether a task finished), which nothing else can answer.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Social.Notifications

  prop activity_id, :any, default: nil
  prop object, :any, default: nil
  prop object_id, :any, default: nil
  prop peered, :any, default: nil
  # the reacting actor's own peered (@peered describes the object's creator)
  prop subject_peered, :any, default: nil
  # prop reply_to_id, :any, default: nil
  # prop profile, :any, default: nil
  # prop character, :any, default: nil
  # the verb the activity was stored as, and what it was for whoever is reading it. Both atoms: this component's own decisions turn on the second, and the word it prints is computed here rather than handed down
  prop verb, :atom, default: nil
  prop experienced_as, :atom, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil

  # decided by `Bonfire.UI.Social.ActivityLive.published_in_placement/2`, never re-derived here, so the card and its subject line can't disagree
  prop published_in_placement, :atom, default: :hidden
  prop published_in_path, :any, default: nil
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

  @doc """
  The icon for what the activity was, from the same declarations the chip bar reads.

  Nothing is listed here: `Bonfire.Social.Notifications.icon_for/2` resolves the category's icon, then the verb's, and the stored verb is the last fallback for a kind no verb declares (something written is a `create`). These rows want the filled variant of whatever it finds, since the registry declares `-duotone` for the boundaries UI.
  """
  def notification_icon(experience, verb \\ nil) do
    case Bonfire.Social.Notifications.icon_for(experience, verb) do
      icon when is_binary(icon) -> String.replace_suffix(icon, "-duotone", "-fill")
      _ -> nil
    end
  end

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

  @doc "Whether a boost's attribution line is redundant here: the group or topic auto-boosted its own content (the publication context row already says so), or we're viewing inside it. A person's manual boost still needs attribution, and notification/widget rows always keep the line since they exist to say who acted."
  def hide_boost_reason?(:boost, subject_id, published_in, showing_within)
      when showing_within not in [:widget, :notifications] do
    Bonfire.UI.Social.Activity.PublishedInLive.published_in_implied_by_context?(showing_within) or
      (not is_nil(published_in) and subject_id == id(published_in))
  end

  def hide_boost_reason?(_verb, _subject_id, _published_in, _showing_within), do: false

  @doc """
  What a row says happened ("liked your activity", "scheduled for tomorrow").

  The categories declare the sentence per kind, read by `Bonfire.Social.Notifications.phrase_for/3`, so a push body and a digest line say the same thing as this row. What stays here is the wording that reads an object's own state, since only something holding the object can say whether a task finished or when it is due.

  `nil` when neither has anything to say, and the caller shows the plain word instead. `current_user_id` comes in already resolved from the context, so "followed you" can differ from "followed".
  """
  def notification_phrase(experience, object_id, current_user_id, object) do
    Notifications.phrase_for(experience, object_id, current_user_id) ||
      object_state_phrase(experience, object)
  end

  @doc """
  Wording that reads the object's own state: a schedule's due date, whether a label finished, who an assignment names. Not declarable alongside the others, since the sentence depends on data only the object carries.

  Third-person-neutral (no "you"/"your"), so a feed reason-line can share it with the notifications header without borrowing notification framing. `nil` when the object says nothing (a schedule with no due date), and the caller shows the plain word.
  """
  def object_state_phrase(:schedule, object) do
    case e(object, :due, nil) do
      nil -> nil
      due -> l("scheduled for %{date}", date: DatesTimes.date_from_now(due))
    end
  end

  def object_state_phrase(:label, object) do
    case e(object, :finished, nil) do
      true -> l("completed")
      false -> l("re-opened")
      _ -> nil
    end
  end

  def object_state_phrase(experience, object) when experience in [:assign, :appoint] do
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
