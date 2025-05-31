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

  prop depth_loaded, :any, default: nil
  prop total_replies_in_thread, :any, default: 0
  prop index, :any, default: 0
  prop thread_object, :any
  prop thread_level, :number, default: 1
  prop threaded_replies, :any
  prop thread_id, :any
  prop feed_id, :any, default: nil
  prop thread_mode, :any, default: nil
  prop showing_within, :atom, default: :thread
  # prop page, :any, default: "thread"
  # prop create_object_type, :any, default: nil
  prop current_url, :string, default: nil
  prop activity_inception, :any, default: nil
  prop hide_actions, :any, default: false

  prop activity_preloads, :tuple, default: {nil, nil}

  def update(%{insert_stream: {:threaded_replies, entries, at}} = assigns, socket) do
    debug("branch is being poured into")

    # ui_compact = assigns[:__context__][:ui_compact] || assigns(socket)[:__context__][:ui_compact]

    {
      :ok,
      socket
      |> assign(Map.drop(assigns, [:insert_stream]))
      |> assign(
        :threaded_replies_count,
        e(assigns(socket), :threaded_replies_count, 0) + length(entries || [])
      )
      |> LiveHandler.insert_comments(
        {:threaded_replies, entries ++ e(assigns(socket), :threaded_replies, []), at}
      )
      #  |> assign_global(
      #    ui_compact: ui_compact || assigns[:thread_level] >= LiveHandler.max_depth(ui_compact) / 2
      #  )
    }
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       :threaded_replies_count,
       length(assigns[:threaded_replies] || assigns(socket)[:threaded_replies] || [])
     )}
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
end
