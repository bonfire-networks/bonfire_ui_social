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

  def update(%{insert_stream: {:threaded_replies, entries, at}} = assigns, socket) do
    debug("branch is being poured into")

    {
      :ok,
      socket
      |> assign(Map.drop(assigns, [:insert_stream]))
      |> assign(
        :threaded_replies_count,
        e(assigns(socket), :threaded_replies_count, 0) + length(entries || [])
      )
      |> assign_show_thread_lines(assigns)
      |> LiveHandler.insert_comments(
        {:threaded_replies, entries ++ e(assigns(socket), :threaded_replies, []), at}
      )
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
