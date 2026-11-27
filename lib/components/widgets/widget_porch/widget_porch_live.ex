# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.UI.Social.WidgetPorchLive do
  @moduledoc """
  "Around <instance> today": what happened on this instance lately, so Home feels lived in. It lists milestones only (new discussions and new events, never replies, likes or boosts) and the people who joined this week, with a "Say hi" that opens the composer mentioning them.

  Public only: the list is loaded once as a guest and cached for an hour for everyone, so it never shows what only some members may see (milestones in private groups never appear). Joining a group and creating one make no activity yet (see the TODO in `Bonfire.Classify.Categories.join/3`), so they are not listed.

  On a day with nothing new it says so once and shows the last few milestones of the week under their day, rather than hiding.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.DatesTimes

  declare_widget(l("Around the instance"), id: :porch, skeleton: :list)

  prop widget_title, :string, default: nil

  # milestones shown on a day with news, and on a quiet day
  @limit 4
  @quiet_limit 3
  @days 7
  @cache_ttl :timer.minutes(60)

  @doc "This week's public local milestones (newest first) and newcomers, cached for everyone for an hour."
  def load(opts \\ []) do
    Cache.maybe_apply_cached(
      &do_load/0,
      [],
      opts
      |> Keyword.put(:cache_key, "widget_porch")
      |> Keyword.put_new(:expire, @cache_ttl)
    )
  end

  defp do_load do
    # as a guest, so the one cached list holds only what everyone may see
    {_circle, as_guest} = Bonfire.Boundaries.Circles.query_as_circle(nil)

    %{
      milestones:
        (list_created(:post, as_guest) ++ list_created("Event", as_guest))
        |> Enum.sort_by(&id(&1.activity), :desc),
      newcomers: list_newcomers()
    }
  end

  # thread roots only: `:create` leaves out replies, boosts and likes of the same objects
  defp list_created(object_type, as_guest) do
    case Bonfire.Social.FeedLoader.feed(
           :custom,
           %{
             origin: :local,
             activity_types: [:create],
             object_types: [object_type],
             time_limit: @days
           },
           as_guest ++
             [
               paginate: %{limit: @limit + 1},
               preload: [:with_subject, :with_post_content, :with_replied],
               skip_err: true
             ]
         ) do
      %{edges: edges} when is_list(edges) -> edges
      _ -> []
    end
  end

  # local people visible to guests (those who chose not to be discoverable are left out), newest first
  defp list_newcomers do
    since = DatesTimes.past(@days, :day)

    case Bonfire.Me.Users.list_paginated(paginate: [limit: 6]) do
      %{edges: users} when is_list(users) -> users
      users when is_list(users) -> users
      _ -> []
    end
    |> Enum.filter(&joined_since?(&1, since))
  end

  defp joined_since?(user, since) do
    case DatesTimes.date_from_pointer(user) do
      %DateTime{} = joined -> DateTime.compare(joined, since) == :gt
      _ -> false
    end
  end

  @doc "What to show, as `{:today | :quiet, milestones, how many more today}`: today's milestones, else (a quiet day) the last few of the week."
  def shown(milestones) do
    case Enum.filter(milestones, &(day(&1) == Date.utc_today())) do
      [] -> {:quiet, Enum.take(milestones, @quiet_limit), 0}
      today -> {:today, Enum.take(today, @limit), length(today) - @limit}
    end
  end

  @doc "Busts the cached list (recomputed on the next read); the widget's refresh button, for moderators."
  def handle_event("reset_porch", _params, socket) do
    load(cache: :reset)

    {:noreply,
     assign_flash(
       socket,
       :info,
       l("The list has been reset.") <> " " <> l("You need to reload to see updates, if any.")
     )}
  end

  @doc "The milestones grouped under their day, newest day first."
  def by_day(milestones) do
    milestones
    |> Enum.chunk_by(&day/1)
    |> Enum.map(&{day(hd(&1)), &1})
  end

  defp day(%{activity: activity}) do
    case DatesTimes.date_from_pointer(activity) do
      %DateTime{} = dt -> DateTime.to_date(dt)
      _ -> nil
    end
  end

  @doc "The heading of a day: Today, Yesterday, else its weekday."
  def day_label(date) do
    case Date.diff(Date.utc_today(), date) do
      0 -> l("Today")
      1 -> l("Yesterday")
      _ -> DatesTimes.format_date(date, format: "EEEE")
    end
  end

  @doc "A milestone's object title: its name, else the start of its summary or text."
  def title(activity) do
    case e(activity, :object, :post_content, :name, nil) do
      name when is_binary(name) ->
        name

      _ ->
        (e(activity, :object, :post_content, :summary, nil) ||
           e(activity, :object, :post_content, :html_body, nil))
        |> Text.text_only()
        |> Text.sentence_truncate(80, "…")
    end
  end

  @doc "Whether the milestone is an event (else a discussion)."
  def event?(activity),
    do: Bonfire.Common.Types.object_type(e(activity, :object, nil)) == Bonfire.Gatherings.Event

  @doc "The text that pre-fills the composer for \"Say hi\": a mention of each newcomer except the viewer."
  def hello_text(newcomers, current_user) do
    newcomers
    |> Enum.reject(&(id(&1) == id(current_user)))
    |> Enum.map_join(" ", &("@" <> e(&1, :character, :username, "")))
    |> Kernel.<>(" ")
  end
end
