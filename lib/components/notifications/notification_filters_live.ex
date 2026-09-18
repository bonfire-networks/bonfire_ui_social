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

  An entry naming a `preset` takes its label, icon and the verbs it filters by from that feed
  preset, and appears only when the preset's own gate permits it
  (`Feeds.feed_preset_if_permitted/2`, which is how `instance_permission_required` and
  `current_user_required` are already enforced for presets), so a chip needs no permission
  vocabulary of its own. Its path still comes from its key, so it narrows this feed like any other
  chip rather than navigating away to the preset's own feed.
  """
  def chips(context \\ nil) do
    Config.get([__MODULE__, :notification_chips], [],
      name: l("Notification categories"),
      description: l("Which category chips to offer on the notifications feed.")
    )
    |> Enum.flat_map(&from_feed_preset(&1, context))
  end

  defp from_feed_preset({key, %{preset: preset_key} = chip}, context) do
    case Bonfire.Social.Feeds.feed_preset_if_permitted(preset_key, context) do
      {:ok, preset} ->
        [
          {key,
           %{
             name_pluralized: e(chip, :name_pluralized, nil) || e(preset, :name, nil),
             icon: e(chip, :icon, nil) || e(preset, :icon, nil),
             description: e(chip, :description, nil) || e(preset, :description, nil),
             path_aliases: e(chip, :path_aliases, [])
           }}
        ]

      _not_permitted ->
        []
    end
  end

  defp from_feed_preset(entry, _context), do: [entry]

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

  Chips are matched first (by key or by any of their aliases), then any declared verb, so a
  category with no chip still has a URL. A chip only declares `filters` when they differ from
  "activities of the verb my key names", and only declares a `preset` when it shows a different feed
  (in which case that preset supplies the filters, so there are no extra ones).
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
        case e(chip, :preset, nil) do
          nil -> {key, default_preset(), e(chip, :filters, nil) || default_filters(key)}
          preset -> {key, preset, %{}}
        end
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
