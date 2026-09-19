defmodule Bonfire.UI.Social.NotificationPreferencesLive do
  @moduledoc """
  Notification preferences.

  Sections whose backend isn't built yet render only when the app-wide `:show_unimplemented` flag
  is on, and each drops its check as it is wired up.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Social.Notifications

  @doc """
  Where this panel is being shown: `:feed` next to the feed it configures, otherwise on its own (settings).

  Two things differ for `:feed`. It starts collapsed, since the Preferences button is what opens it, and it offers to re-query the feed once switches have been saved. On its own there is no feed to catch up and nothing to expand, so it is open and the offer is not made. Everything else, including every switch, is the same panel.
  """
  prop showing_within, :any, default: nil

  @doc "The shown feed's filters, so the panel can tell whether saved switches have been applied."
  prop feed_filters, :any, default: %{}

  @doc "The shown feed's display assigns, for the same comparison."
  prop feed_assigns, :any, default: %{}

  @doc "Which settings scope the panel is being shown for, when it is shown in settings."
  prop scope, :any, default: nil

  @doc """
  The settings key holding whether a category is pushed to this person's devices.

  The same shape as the key beside it in each row (`Notifications.show_in_centre_key/1`), and the same grain: one switch per category per channel, which is what `Bonfire.Notify.Preferences` reads when it decides whether to deliver.
  """
  def push_key(key), do: [:notifications, :push, key]

  @doc """
  Whether to offer the push column at all, which is whether anything would read it.

  Asked of the module that does the reading, since this panel lives with the feed it configures and the delivery side is a separate extension an instance can do without. Offering a switch nothing honours is the same fault as the rows whose own switch is not wired yet.
  """
  def push_available?(context), do: module_enabled?(Bonfire.Notify.Preferences, context)

  @doc "Display switches to offer, in display order, from config."
  def display_toggles do
    Config.get([__MODULE__, :display_toggles], [],
      name: l("Notification display options"),
      description: l("Which display switches to offer on the notifications feed.")
    )
  end

  @doc "Whether a display switch is on for this user, falling back to the switch's own default."
  def display_on?(key, context) do
    Settings.get([__MODULE__, :display, key], default_for(key), context)
  end

  defp default_for(key), do: display_toggles() |> e(key, :default, false)

  @doc "The settings key a display switch writes to, so the UI and the feed read the same place."
  def display_setting_key(key), do: [__MODULE__, :display, key]

  @doc """
  What a display switch controls: `{:filter, key}` for a feed filter, `{:assign, key}` for a feed
  assign, or `{:controls, key}` for something this UI handles itself (eg. the chip bar).
  """
  def display_target(key) do
    toggle = display_toggles() |> e(key, nil)

    cond do
      filter = e(toggle, :filter, nil) -> {:filter, filter}
      assign = e(toggle, :assign, nil) -> {:assign, assign}
      controls = e(toggle, :controls, nil) -> {:controls, controls}
      true -> nil
    end
  end

  @doc """
  Whether the shown feed is out of date with this user's saved display switches.

  Derived rather than tracked: the switches save immediately, and the feed only catches up when
  something reloads it, so compare what the settings now say against what the feed is showing.
  Switches that only control this UI (the chip bar) apply instantly and never count as pending.
  """
  def display_pending?(context, feed_filters, feed_assigns) do
    # against what the shown feed asked for, so a category's own chip doesn't read as out of date for showing it
    {filters, assigns} = display_overrides(context, e(feed_filters, :activity_types, []))

    Enum.any?(filters, fn {key, wanted} -> !same_value?(e(feed_filters, key, nil), wanted) end) or
      Enum.any?(assigns, fn {key, wanted} -> !same_value?(e(feed_assigns, key, nil), wanted) end)
  end

  defp same_value?(shown, wanted), do: comparable(shown) == comparable(wanted)

  # a list filter can come back from the feed in another order or as strings, and `false`, `[]` and an unset key all mean the same to the query
  defp comparable(value) when value in [nil, [], false], do: false
  defp comparable(value) when is_list(value), do: value |> Enum.map(&to_string/1) |> Enum.sort()
  defp comparable(value), do: value

  @doc """
  Feed filters and assigns implied by this user's display switches and "Notify me about" switches.

  `FeedLoader` already applies the "Notify me about" exclusions to every notifications read, so the
  query does not need them from here. This page does: the `feed_filters` assign is built from the
  preset's filters (`feed_default_assigns_from_preset/2`) rather than from what the loader prepared,
  and the Apply button works by comparing these against that assign. The loader unions, so saying it
  twice changes no query.

  `showing` is the activity types the view asks for, which outrank a "Notify me about" switch.
  """
  def display_overrides(context, showing \\ []) do
    {filters, assigns} =
      Enum.reduce(display_toggles(), {%{}, []}, fn {key, _toggle}, {filters, assigns} ->
        on? = display_on?(key, context)

        case display_target(key) do
          {:filter, filter} -> {Map.put(filters, filter, on?), assigns}
          {:assign, assign} -> {filters, Keyword.put(assigns, assign, on?)}
          _ -> {filters, assigns}
        end
      end)

    {Map.put(
       filters,
       :exclude_activity_types,
       Notifications.excluded_activity_types(context, showing)
     ), assigns}
  end

  @doc """
  Rows of the "Notify me about" table: `{key, label, whether its switch is wired}`, in config order.

  The categories, their order and their labels come from `Bonfire.Social.Notifications`, the same
  declaration the chips read, so a switch can't hide something other than what its chip shows.
  """
  def notification_rows do
    Notifications.categories_shown(:row)
    |> Enum.map(fn {key, _category} ->
      {key, Notifications.label_for(key), Notifications.implemented?(key, :row)}
    end)
  end

  @doc "Audience options shown as a design preview, not implemented policies."
  def audience_types do
    [
      {"not_followed", l("People you don’t follow"),
       l("Accounts outside the people you follow.")},
      {"not_following", l("People not following you"), l("Accounts that don’t follow you.")},
      {"new", l("New accounts"), l("Accounts created in the past 30 days.")},
      {"private", l("Unsolicited private mentions"),
       l("Private mentions outside an existing conversation.")},
      {"moderated", l("Moderated accounts"), l("Accounts limited by instance moderators.")},
      {"bots", l("Bots"), l("Accounts marked as automated.")}
    ]
  end
end
