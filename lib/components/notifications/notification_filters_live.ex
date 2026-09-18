defmodule Bonfire.UI.Social.NotificationFiltersLive do
  @moduledoc """
  Category chips for the notifications feed.

  Each chip is a link, not an event, so a filtered view is shareable and the back button works.
  The chip list is declared in config (see `Bonfire.UI.Social.RuntimeConfig`); a URL segment
  resolves against that list first and then against the verb registry, so every declared verb has
  a working URL whether or not a chip is shown for it.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Boundaries.Verbs

  @doc "Which chip is being viewed; nil means the unfiltered feed."
  prop selected_tab, :any, default: nil

  @base_path "/notifications"
  @doc "The chip whose view is the unfiltered feed, and so has no URL segment of its own."
  @default_chip :latest

  @doc """
  Chips to render, in display order, from config.

  Every chip is a feed preset plus a narrowing. The narrowing is what `filters` holds; a reload of an already-mounted feed has to merge it onto the preset's own filters (`Feeds.preset_filters/2`), or it silently drops preset settings and loads an unbounded, ungrouped feed, while a first load passes the narrowing alone because it resolves the preset itself. Label and icon fall back to the preset's.

  A chip may name its own `preset` to show a different feed, and then that preset's gate decides whether the chip appears at all (`Feeds.feed_preset_if_permitted/2`, which is how `instance_permission_required` and `current_user_required` are enforced for presets), so a chip needs no permission vocabulary of its own. Chips that don't name one use `default_preset/0` purely as a source of filters, and stay visible regardless of its gate.
  """
  def chips(context \\ nil) do
    Config.get([__MODULE__, :notification_chips], [],
      name: l("Notification categories"),
      description: l("Which category chips to offer on the notifications feed.")
    )
    |> Enum.flat_map(&from_feed_preset(&1, context))
  end

  defp from_feed_preset({key, chip}, context) do
    named_preset = e(chip, :preset, nil)

    case Bonfire.Social.Feeds.feed_preset_if_permitted(named_preset || default_preset(), context) do
      {:ok, preset} ->
        [{key, from_preset(key, chip, preset)}]

      _not_permitted ->
        # a chip that NAMES a preset belongs to that feed, so its gate hides the chip; the default preset is only where filters come from, so keep the chip and narrow nothing
        if named_preset, do: [], else: [{key, chip}]
    end
  end

  defp from_preset(key, chip, preset) do
    %{
      name_pluralized: e(chip, :name_pluralized, nil) || e(preset, :name, nil),
      icon: e(chip, :icon, nil) || e(preset, :icon, nil),
      description: e(chip, :description, nil) || e(preset, :description, nil),
      preset: e(chip, :preset, nil),
      # the narrowing only: merged onto the preset's own filters by whoever reloads a mounted feed, but passed alone to a first load, which resolves the preset itself
      filters: e(chip, :filters, nil) || default_filters(key),
      path_aliases: e(chip, :path_aliases, [])
    }
  end

  @doc """
  The URL for a chip: the first of its `path_aliases` when set, else its key.

      iex> Bonfire.UI.Social.NotificationFiltersLive.chip_path(:latest, %{})
      "/notifications"

      iex> Bonfire.UI.Social.NotificationFiltersLive.chip_path(:like, %{path_aliases: ["likes"]})
      "/notifications/likes"

      iex> Bonfire.UI.Social.NotificationFiltersLive.chip_path(:flag, %{})
      "/notifications/flag"
  """
  def chip_path(@default_chip, _chip), do: @base_path

  def chip_path(key, chip) do
    "#{@base_path}/#{List.first(e(chip, :path_aliases, [])) || key}"
  end

  @doc """
  Resolves a URL segment to `{chip key, feed preset, extra filters}`, or `nil` when it names nothing.

  Chips are matched first (by key or by any of their aliases), then any declared verb, so a category with no chip still has a URL. The filters returned are already complete (preset merged with narrowing, see `chips/1`); a chip config entry only states `filters` when they differ from "activities of the verb my key names".
  """
  def resolve_segment(segment, context \\ nil)

  def resolve_segment(segment, context) when is_binary(segment) do
    # with context, so a chip gated by its preset still resolves for whoever it is shown to
    resolve_chip(segment, context) || resolve_verb(segment)
  end

  def resolve_segment(_, _), do: nil

  @doc "The feed preset a chip shows when it doesn't name one of its own."
  def default_preset, do: :notifications

  defp resolve_chip(segment, context) do
    Enum.find_value(chips(context), fn {key, chip} ->
      if to_string(key) == segment or segment in e(chip, :path_aliases, []) do
        # `chips/1` has already merged the preset's filters with this chip's narrowing
        {key, e(chip, :preset, nil) || default_preset(), e(chip, :filters, nil) || %{}}
      end
    end)
  end

  # the default chip is the whole feed; any other names the verb it filters by
  defp default_filters(@default_chip), do: %{activity_types: []}
  defp default_filters(key), do: %{activity_types: [key]}

  defp resolve_verb(segment) do
    with verb when is_atom(verb) <- Types.maybe_to_atom!(segment),
         %{} <- Verbs.get(verb) do
      {verb, default_preset(), %{activity_types: [verb]}}
    else
      _ -> nil
    end
  end

  @doc """
  Whether a chip is the one being viewed.

  Anything naming no chip (nil, or the feed name that `feed_default_assigns` puts in
  `selected_tab`) means the default chip.

      iex> Bonfire.UI.Social.NotificationFiltersLive.current?(:like, :like)
      true

      iex> Bonfire.UI.Social.NotificationFiltersLive.current?(:like, :notifications)
      false

      iex> Bonfire.UI.Social.NotificationFiltersLive.current?(:latest, :notifications)
      true
  """
  def current?(key, selected_tab) do
    to_string(key) ==
      if(chip_key?(selected_tab), do: to_string(selected_tab), else: to_string(@default_chip))
  end

  # a chip key is the default chip or a verb, which distinguishes it from a feed name without needing the context a gated chip would (`chips/1` hides those)
  defp chip_key?(name) do
    to_string(name) == to_string(@default_chip) or
      not is_nil(Verbs.get(Types.maybe_to_atom!(name) || :none))
  end

  @doc "A chip's `name_pluralized` OVERRIDE, else the verb's own (singular) name, else its key."
  def chip_label(key, chip) do
    e(chip, :name_pluralized, nil) || e(Verbs.get(key), :verb, nil) || to_string(key)
  end

  @doc "A chip's `icon` OVERRIDE, else the verb's own (most chips declare none and inherit it)."
  def chip_icon(key, chip) do
    e(chip, :icon, nil) || e(Verbs.get(key), :icon, nil)
  end
end
