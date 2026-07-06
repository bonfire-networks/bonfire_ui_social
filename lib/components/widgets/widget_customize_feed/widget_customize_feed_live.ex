defmodule Bonfire.UI.Social.WidgetCustomizeFeedLive do
  @moduledoc """
  Sidebar widget applying the calm-empowerment pattern (see `Bonfire.UI.Common.Settings.Calm.PresetCardsLive` & co) to feed customization. The two visible layers deliberately vary DIFFERENT filter dimensions so they compose instead of overlapping:

  1. preset cards pick the CONTENT MIX & RANKING (activity/object/media types + sort_by): everything / focus / reading / most replied / most boosted;
  2. override toggles for the most common adjustments: the feed source (following vs everything known to the instance), group activities (subject-type dimension), and hide replies / hide boosts shortcuts (these two touch the cards' dimension, so flipping one under a preset reads as customizing away from it);
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

  # The filter dimensions a preset card owns (content types + ranking). Every bundle
  # explicitly resets ALL of them, so switching cards fully replaces the mix while leaving
  # Level-2 scope (time_limit / exclude_subjects) untouched — except the popularity cards,
  # which do set time_limit (ranking all-time by count would surface ancient greatest hits;
  # the Recent-only toggle simply shows as ON and stays composable).
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
  # two dimensions (see FeedLoader.do_apply_filters), so research publications
  # (media_types: [:research]) can't join the reading card.
  @preset_bundles [
    {"default", %{}},
    {"focus",
     %{
       object_types: [:post],
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
        description: l("Posts, replies, boosts, likes and follows.")
      },
      %{
        value: "focus",
        name: l("Focus"),
        icon: "ph:crosshair-simple-duotone",
        description: l("Only top-level posts.")
      },
      %{
        value: "discussions",
        name: l("Most replied"),
        icon: "ph:chats-circle-duotone",
        description: l("This week's most replied conversations.")
      },
      %{
        value: "trending",
        name: l("Most boosted"),
        icon: "ph:trend-up-duotone",
        description: l("This week's most boosted posts.")
      }
    ]
  end

  @doc "The filters a preset card applies: its bundle merged over an explicit reset of every dimension the cards own (empty type lists + `sort_by: false`, which `FeedLive.set_filters` translates to \"remove the sort\" since a nil wouldn't survive the merge). Nil for an unknown value."
  def preset_filters(value) do
    case List.keyfind(@preset_bundles, to_string(value), 0) do
      {_, bundle} ->
        Map.new(@content_type_keys, &{&1, []})
        |> Map.put(:sort_by, false)
        |> Map.merge(bundle)

      _ ->
        nil
    end
  end

  @doc "Which preset card matches the current content-type + sort filters (scope filters like time/subjects are ignored, so Level-2 toggles don't un-match the card). \"custom\"/no highlight when none does."
  def current_preset(feed_filters) do
    signature = content_signature(feed_filters)

    Enum.find_value(@preset_bundles, "custom", fn {value, bundle} ->
      if signature == content_signature(bundle), do: value
    end)
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
          name: l("Include group activities"),
          # description: l("Activities shared into groups you follow."),
          on: group_activities_included?(feed_filters)
        },
        %{
          key: :replies,
          name: l("Hide replies"),
          # description: l("Skip conversation replies."),
          on: FeedExtraControlsLive.replies_excluded?(feed_filters)
        },
        %{
          key: :boosts,
          name: l("Hide boosts"),
          # description: l("Skip re-shared posts."),
          on: FeedExtraControlsLive.boosts_excluded?(feed_filters)
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

  @doc "Whether activities subject-ed by groups/categories are included (the default: true unless a group subject-type exclusion is set)."
  def group_activities_included?(feed_filters) do
    List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
    |> Enum.all?(&(to_string(&1) not in @group_subject_types))
  end

  @doc "The exclude_subject_types list with the group/category exclusion toggled on or off (other subject-type exclusions are preserved)."
  def exclude_subject_types_toggling_groups(feed_filters, include?) do
    rest =
      List.wrap(e(feed_filters, :exclude_subject_types, []) || [])
      |> Enum.reject(&(to_string(&1) in @group_subject_types))

    # NB must be the schema module: `Types.table_types/1` resolves the :group/"group"
    # aliases back to the :group ATOM (not the schema) so they yield no table id and the
    # query filter would silently not apply
    if include?, do: rest, else: rest ++ [Bonfire.Classify.Category]
  end
end
