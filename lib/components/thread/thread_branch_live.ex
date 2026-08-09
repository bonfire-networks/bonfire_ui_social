defmodule Bonfire.UI.Social.ThreadBranchLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Untangle
  # alias Bonfire.Fake
  #
  # alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.CreateUserLive
  alias Bonfire.Social.Threads.LiveHandler
  alias Bonfire.UI.Social.CommentLive
  # alias Bonfire.UI.Social.ThreadBranchLive
  # import Bonfire.Me.Integration
  prop comment, :map

  prop total_replies_in_thread, :any, default: 0
  prop index, :any, default: 0
  prop thread_object, :any
  prop thread_level, :number, default: 1
  prop threaded_replies, :any
  prop thread_id, :any
  prop highlight_reply_id, :any, default: nil
  prop feed_id, :any, default: nil
  prop thread_mode, :any, default: nil
  prop showing_within, :atom, default: :thread
  # prop page, :any, default: "thread"
  # prop create_object_type, :any, default: nil
  prop current_url, :string, default: nil
  prop activity_inception, :any, default: nil
  prop hide_actions, :any, default: false
  prop depth_loaded, :any, default: nil

  prop activity_preloads, :tuple, default: {nil, nil}

  # total replies in the whole thread (not just this branch), used by the auto-collapse policy
  prop thread_reply_count, :any, default: nil

  # localized "N months later"/"N years earlier" divider shown above this comment when
  # it arrived long after (or before, in newest-first order) the sibling displayed above it
  prop time_gap_before, :any, default: nil

  # nil = follow the `collapse_replies?/3` policy; false = force-expanded (set when a live reply is pushed into this branch)
  data collapse_replies, :any, default: nil

  def update(%{insert_stream: {:threaded_replies, entries, at}} = assigns, socket) do
    debug("branch is being poured into")

    # No stream here (plain `assign`/`{#for}`), so dedup by id ourselves —
    # incoming wins, matching stream_insert — since the same reply can be
    # delivered twice (live_push hits both the thread_id and reply_to_id topics).
    existing = e(assigns(socket), :threaded_replies, [])
    merged = Enum.uniq_by(entries ++ existing, fn {entry, _children} -> id(entry) end)
    added = max(length(merged) - length(existing), 0)

    socket =
      socket
      |> assign(Map.drop(assigns, [:insert_stream]))
      |> assign(
        :threaded_replies_count,
        e(assigns(socket), :threaded_replies_count, 0) + added
      )

    {
      :ok,
      socket
      # Use socket assigns: PubSub updates only pass `insert_stream`, so the
      # incoming `assigns` map lacks `thread_level`/`thread_mode`/`showing_within`
      # and would otherwise reset the visual indentation to defaults.
      |> assign_show_thread_lines(assigns(socket))
      # a live-pushed reply must be visible, so never leave this branch collapsed
      |> assign(:collapse_replies, false)
      |> LiveHandler.insert_comments({:threaded_replies, merged, at})
    }
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       :threaded_replies_count,
       length(assigns[:threaded_replies] || assigns(socket)[:threaded_replies] || [])
     )
     |> assign_show_thread_lines(assigns)}
  end

  def render(assigns) do
    # memoized: the template reads the collapse decision in ~9 places
    assigns
    |> assign(:collapsed, collapsed?(assigns))
    |> render_sface()
  end

  @default_max_visual_depth 3

  defp assign_show_thread_lines(socket, assigns) do
    max_depth =
      Bonfire.Common.Settings.get(
        [:ui, :thread, :max_visual_depth],
        @default_max_visual_depth,
        current_user: current_user(assigns)
      )

    thread_level = assigns[:thread_level] || 1

    socket
    |> assign(
      :show_thread_lines,
      assigns[:showing_within] != :messages && assigns[:thread_mode] != :flat
    )
    |> assign(:visual_level, min(thread_level, max_depth))
    |> assign(:parent_visual_level, min(max(thread_level - 1, 0), max_depth))
  end

  def has_replies?(replies), do: replies not in [nil, [], {}, [{}]]

  @auto_collapse_thread_size 10
  @auto_collapse_subtree_size 3

  @doc """
  Whether this branch's replies should currently be collapsed.

  Must be computed at render time, not stored in `update/2`: a stream-inserted branch receives its props across several update cycles, so an update-time decision races with the final rendered values. The stored `collapse_replies` assign only acts as a force-expand override.
  """
  def collapsed?(assigns) do
    assigns[:collapse_replies] != false &&
      collapse_replies?(assigns[:comment], assigns[:threaded_replies], assigns)
  end

  @doc """
  Whether a branch's replies should start collapsed behind a summary row.

  Small threads (< #{@auto_collapse_thread_size} replies) stay fully open; in larger threads only heavy subtrees (#{@auto_collapse_subtree_size}+ nested replies) fold. Logged-in only (expanding needs LiveView running for the client-side `JS` commands), and never hides the subtree containing the permalinked/highlighted reply.
  """
  def collapse_replies?(comment, threaded_replies, assigns) do
    not is_nil(current_user_id(assigns)) &&
      assigns[:showing_within] not in [:messages, :smart_input] &&
      assigns[:thread_mode] != :flat &&
      has_replies?(threaded_replies) &&
      (assigns[:thread_reply_count] || 0) >= @auto_collapse_thread_size &&
      sub_replies_count(comment) >= @auto_collapse_subtree_size &&
      !contains_reply?(threaded_replies, assigns[:highlight_reply_id])
  end

  @doc "Recursively checks whether a reply id appears in an arranged `{reply, children}` tree."
  def contains_reply?(_tree, nil), do: false

  def contains_reply?(tree, reply_id) when is_list(tree) do
    Enum.any?(tree, fn
      {reply, children} -> id(reply) == reply_id or contains_reply?(children, reply_id)
      _ -> false
    end)
  end

  def contains_reply?(_, _), do: false

  @doc """
  The client-side command chain that swaps a branch between collapsed and expanded.

  Auto-collapsed branches include the `+/−` junction button in the chain (the summary row is their expand affordance) but never toggle the trunk line — it stays visible in both states, connecting the comment's avatar to the summary elbow. Manual collapse has no summary row, so the line toggles along with the replies.
  """
  def collapse_toggle_js(id, auto_collapsed?) do
    js =
      JS.toggle(to: "#replies-#{id}")
      |> JS.toggle(to: "#collapse-minus-#{id}")
      |> JS.toggle(to: "#collapse-plus-#{id}")
      |> JS.toggle(to: "#collapse-summary-#{id}")

    # display: "flex" because JS.toggle re-shows as display:block, breaking the button's flex centering
    if auto_collapsed?,
      do: JS.toggle(js, to: "#collapse-toggle-#{id}", display: "flex"),
      else: JS.toggle(js, to: "#line-#{id}")
  end

  # gaps shorter than this between adjacent comments don't get a time-gap marker
  @time_gap_min_days 90

  @doc """
  Localized time-gap divider text between two comments, or nil when they're close in time.

  Bidirectional: a positive gap (reading down goes forward in time) says "later", a negative one (newest-first order, e.g. one fresh reply atop a necro'd pile) says "earlier". Timestamps come from the comments' ULIDs, so no extra data is needed.
  """
  def time_gap_label(prev, current) do
    with %DateTime{} = prev_date <- to_gap_date(prev),
         %DateTime{} = date <- to_gap_date(current) do
      days = div(DateTime.diff(date, prev_date, :second), 86_400)

      cond do
        days >= 365 ->
          lp("%{count} year later", "%{count} years later", div(days, 365), count: div(days, 365))

        days >= @time_gap_min_days ->
          lp("%{count} month later", "%{count} months later", div(days, 30), count: div(days, 30))

        days <= -365 ->
          lp("%{count} year earlier", "%{count} years earlier", div(-days, 365),
            count: div(-days, 365)
          )

        days <= -@time_gap_min_days ->
          lp("%{count} month earlier", "%{count} months earlier", div(-days, 30),
            count: div(-days, 30)
          )

        true ->
          nil
      end
    else
      _ -> nil
    end
  end

  @doc "Time-gap divider for the child at `index` in an arranged `{reply, children}` list: the first child is compared to the parent comment (a fresh reply to an old comment is the classic necro), later ones to the sibling displayed above."
  def time_gap_before(parent, siblings, 0) when is_list(siblings),
    do: time_gap_label(parent, Enum.at(siblings, 0))

  def time_gap_before(_parent, siblings, index)
      when is_list(siblings) and is_integer(index) and index > 0,
      do: time_gap_label(Enum.at(siblings, index - 1), Enum.at(siblings, index))

  def time_gap_before(_, _, _), do: nil

  defp to_gap_date(%DateTime{} = date), do: date
  defp to_gap_date({entry, _children}), do: to_gap_date(entry)
  defp to_gap_date(nil), do: nil
  defp to_gap_date(other), do: DatesTimes.date_from_pointer(other)

  @doc "Label for the load-more-replies affordance, pluralized (the count can also be an approximation string like `2+` or `~3`)."
  def more_replies_label(comment, threaded_replies_count) do
    case extra_replies_count(comment, threaded_replies_count) do
      count when is_integer(count) ->
        lp("%{count} more reply", "%{count} more replies", count, count: count)

      count ->
        l("%{count} more replies", count: count)
    end
  end

  @doc "Up to `limit` distinct authors of the direct replies in an arranged branch, for the collapsed summary row."
  def reply_authors(threaded_replies, limit \\ 3) do
    (threaded_replies || [])
    |> Enum.map(fn
      {reply, _children} -> CommentLive.get_activity(reply) |> e(:subject, nil)
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&id/1)
    |> Enum.take(limit)
  end

  def show_more_replies_button?(comment, thread_level, depth_loaded, threaded_replies_count) do
    thread_level == depth_loaded and is_integer(threaded_replies_count) and
      (e(comment, :total_replies_count, nil) || e(comment, :replied, :total_replies_count, nil) ||
         0) > threaded_replies_count
  end

  def sub_replies_count(comment) do
    activity = CommentLive.get_activity(comment)

    e(activity, :replied, :nested_replies_count, 0) +
      e(activity, :replied, :direct_replies_count, 0)
  end

  def extra_replies_count(comment, threaded_replies_count) do
    case {(e(comment, :direct_replies_count, nil) ||
             e(comment, :replied, :direct_replies_count, 0)) -
            threaded_replies_count,
          e(comment, :nested_replies_count, nil) ||
            e(comment, :replied, :nested_replies_count, nil) ||
            0} do
      {0, 0} -> ""
      {0, nested} -> "~#{nested}"
      {direct_left, nested} when nested > direct_left -> "#{direct_left}+"
      {direct_left, _} -> direct_left
    end
  end

  def more_siblings_below?(parent_comment, index, loaded_count) do
    total_direct =
      e(parent_comment, :direct_replies_count, nil) ||
        e(parent_comment, :replied, :direct_replies_count, 0) || 0

    effective_total = max(total_direct, loaded_count || 0)

    index < effective_total - 1
  end
end
