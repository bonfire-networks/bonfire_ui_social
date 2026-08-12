defmodule Bonfire.UI.Social.WidgetCustomizeFeedLive do
  @moduledoc """
  Sidebar widget applying the calm-empowerment pattern (see `Bonfire.UI.Common.Settings.Calm.PresetCardsLive` & co) to feed customization. The visible layers deliberately vary different filter dimensions so they compose instead of overlapping:

  1. preset cards pick the content mix and ranking (activity/object/media types + sort_by): everything / focus / most replied / most boosted;
  2. override toggles for the most common adjustments: the feed source (following vs everything known to the instance), group activities (group-authored and group-context content), and replies / boosts visibility (these two touch the cards' dimension, so flipping one under a preset reads as customizing away from it);
  3. the full filter matrix stays behind an explicit gesture: an "Advanced filters" row that directly opens the all-filters modal (`FeedFiltersModalContentLive`).

  All levels post their form events to the `FeedLive` stateful component (via `event_target`), which reloads the feed in place; the widget itself stays stateless and is re-sent by `FeedLive.reload/3` whenever filters change.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.UI.Social.FeedExtraControlsLive

  prop widget_title, :string, default: nil

  @doc "DOM selector of the feed component (e.g. `\"#feed_component_id\"`) that filter events are sent to."
  prop event_target, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop showing_within, :atom, default: nil
  prop feed_filters, :any, default: nil
  prop feed_baseline_filters, :any, default: nil

  # The filter dimensions a preset card owns (content types + ranking). Every bundle
  # explicitly resets all of them, so switching cards fully replaces the mix while leaving
  # scope filters such as time_limit and exclude_subjects untouched — except the popularity
  # cards, which do set time_limit (ranking all-time by count would surface ancient greatest
  # hits, and count-sorting the whole history is an expensive query).
  @content_type_keys [
    :activity_types,
    :exclude_activity_types,
    :object_types,
    :exclude_object_types,
    :media_types,
    :exclude_media_types
  ]

  @preset_signature_keys @content_type_keys ++ [:sort_by]

  @doc "The filter dimensions the preset cards own (used e.g. when switching feed source to decide which filters travel along)."
  def preset_owned_keys, do: @preset_signature_keys

  # preset value -> filters (mirroring the built-in feed presets in
  # Bonfire.Social.RuntimeConfig: :posts / :articles / :books / :trending_discussions /
  # the disabled :trending).
  # NB: never combine object_types AND media_types in one bundle — the loader ANDs the
  # two dimensions (see FeedLoader.do_apply_filters), so a mixed preset must choose
  # one inclusion dimension and express the rest through exclusions.
  @preset_bundles [
    {"default", %{}},
    {"focus",
     %{
       exclude_activity_types: [:reply, :boost, :like, :follow]
     }},
    {"discussions",
     %{
       sort_by: :reply_count,
       time_limit: 7,
       exclude_activity_types: [:boost, :like, :vote, :follow, :reply]
     }},
    {"trending",
     %{
       sort_by: :boost_count,
       time_limit: 7,
       exclude_activity_types: [:reply]
     }}
  ]

  def preset_cards do
    [
      %{
        value: "default",
        name: l("Everything"),
        icon: "ph:sparkle-duotone",
        description: l("The feed's usual mix of activities.")
      },
      %{
        value: "focus",
        name: l("Focus"),
        icon: "ph:crosshair-simple-duotone",
        description: l("Hide replies and boosts.")
      },
      %{
        value: "discussions",
        name: l("Most replied"),
        icon: "ph:chats-circle-duotone",
        description: l("This week's most active conversations.")
      },
      %{
        value: "trending",
        name: l("Most boosted"),
        icon: "ph:trend-up-duotone",
        description: l("This week's popular posts.")
      }
    ]
  end

  @doc "The card describing the current preset, or a localized custom-state summary when the filters no longer match a preset."
  def current_preset_card(feed_filters, baseline_filters \\ %{}) do
    current = current_preset(feed_filters, baseline_filters)

    Enum.find(preset_cards(), &(&1.value == current)) ||
      %{
        value: "custom",
        name: l("Custom"),
        icon: "ph:sliders-horizontal-duotone",
        description: l("Your own mix of feed filters.")
      }
  end

  @doc "The filters a preset card applies over the named feed's canonical content mix. The default restores that baseline; focused/ranked modes preserve its exclusions while adding their own. Nil for an unknown value."
  def preset_filters(value, baseline_filters \\ %{}) do
    case List.keyfind(@preset_bundles, to_string(value), 0) do
      {_, bundle} -> build_preset_filters(bundle, preset_baseline(baseline_filters))
      _ -> nil
    end
  end

  @doc "Which preset card matches the effective content-type + sort filters relative to the named feed's canonical baseline. Scope filters like time/subjects are ignored."
  def current_preset(feed_filters, baseline_filters \\ %{}) do
    baseline = preset_baseline(baseline_filters)

    signature =
      baseline
      |> inherit_current_filters(feed_filters)
      |> content_signature()

    Enum.find_value(@preset_bundles, "custom", fn {value, bundle} ->
      if signature == content_signature(build_preset_filters(bundle, baseline)), do: value
    end)
  end

  defp build_preset_filters(bundle, baseline) do
    Map.new(@content_type_keys, &{&1, []})
    |> Map.put(:sort_by, false)
    |> Map.merge(baseline)
    |> merge_preset_bundle(bundle)
  end

  defp preset_baseline(filters) do
    Enum.reduce(@preset_signature_keys, %{}, fn key, baseline ->
      case e(filters, key, nil) do
        nil -> baseline
        value -> Map.put(baseline, key, value)
      end
    end)
  end

  # A nil current value inherits the feed preset. Explicit []/false values remain meaningful
  # because they clear an inherited list or ranking.
  defp inherit_current_filters(baseline, filters) do
    Map.new(@preset_signature_keys, fn key ->
      value = e(filters, key, nil)
      {key, if(is_nil(value), do: Map.get(baseline, key), else: value)}
    end)
  end

  defp merge_preset_bundle(filters, bundle) do
    baseline_exclusions = List.wrap(Map.get(filters, :exclude_activity_types) || [])
    bundle_exclusions = List.wrap(Map.get(bundle, :exclude_activity_types) || [])

    filters
    |> Map.merge(bundle)
    |> Map.put(
      :exclude_activity_types,
      Enum.uniq_by(baseline_exclusions ++ bundle_exclusions, &to_string/1)
    )
  end

  defp content_signature(filters) do
    Map.new(@preset_signature_keys, fn key ->
      {key,
       (e(filters, key, []) || [])
       |> List.wrap()
       |> Enum.map(&to_string/1)
       |> Enum.sort()}
    end)
  end

  @doc "Level-2 rows for `OverrideTogglesLive`: the most common adjustments, prefilled with the current effective state."
  def override_rows(feed_filters, feed_name, _context) do
    following_row(feed_name) ++
      [
        %{
          key: :group_activity,
          name: l("Group activities"),
          # description: l("Activities shared into groups you follow."),
          on: group_activities_included?(feed_filters)
        },
        %{
          key: :replies,
          name: l("Replies"),
          # description: l("Skip conversation replies."),
          on: not FeedExtraControlsLive.replies_excluded?(feed_filters)
        },
        %{
          key: :boosts,
          name: l("Boosts"),
          # description: l("Skip re-shared posts."),
          on: not FeedExtraControlsLive.boosts_excluded?(feed_filters)
        }
      ]
  end

  # source switch: ON = the Following feed, OFF = everything known to the instance
  # (explore); only meaningful on those two feeds — hidden elsewhere (a named feed like
  # bookmarks or a custom feed has its own source)
  defp following_row(feed_name) when feed_name in [:my, :explore] do
    [
      %{
        key: :following,
        name: l("Only people I follow"),
        on: feed_name == :my
      }
    ]
  end

  defp following_row(_), do: []

  # spellings under which a group/category subject-type exclusion may be stored
  # (we store `:group`; the modal or saved feeds may carry other aliases)
  @group_subject_types [
    "group",
    "groups",
    "category",
    "categories",
    "Group",
    "Category",
    "Elixir.Bonfire.Classify.Category",
    "2AGSCANBECATEG0RY0RHASHTAG"
  ]

  @doc "Whether group/category-authored activities and objects published in a category context are included (the default is true). The switch writes the compound `exclude_group_activities` flag; the other keys are legacy per-dimension spellings from saved feeds or the advanced modal."
  def group_activities_included?(feed_filters) do
    not e(feed_filters, :exclude_group_activities, false) and
      not e(feed_filters, :exclude_category_contexts, false) and
      List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
      |> Enum.all?(&(to_string(&1) not in @group_subject_types))
  end

  @doc """
  The filter updates for switching Group activities on or off — the single place that knows
  which keys the exclusion involves (pair of `group_activities_included?/1`).

  OFF stores just the compound `exclude_group_activities` flag (expanded at query time by
  `FeedLoader.prepare_filters_and_opts`, so no other filter surface can half-clear it);
  ON clears the flag and also sweeps any legacy per-dimension spellings.
  """
  def group_activities_toggle_filters(_feed_filters, false),
    do: %{exclude_group_activities: true}

  def group_activities_toggle_filters(feed_filters, true) do
    %{
      exclude_group_activities: false,
      exclude_subject_types:
        List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
        |> Enum.reject(&(to_string(&1) in @group_subject_types)),
      exclude_category_contexts: false
    }
  end
end
