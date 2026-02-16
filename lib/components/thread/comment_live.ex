defmodule Bonfire.UI.Social.CommentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Social.CommentLive
  alias Bonfire.UI.Social.ActivityLive

  prop index, :any, default: 0
  prop comment, :map
  prop activity, :any, default: nil
  prop total_replies_in_thread, :any, default: 0
  # prop object, :any, default: nil
  prop threaded_replies, :any, default: nil
  prop thread_object, :any
  prop thread_level, :number, default: 0
  prop thread_id, :any
  prop highlight_reply_id, :any, default: nil
  prop feed_id, :any, default: nil
  prop thread_mode, :any, default: nil
  prop showing_within, :atom, default: :thread
  # prop page, :any, default: "thread"
  # prop create_object_type, :any, default: nil
  prop current_url, :string, default: nil
  prop activity_inception, :any, default: nil
  prop ui_compact, :any, default: nil
  prop hide_actions, :any, default: false

  prop activity_preloads, :tuple, default: {nil, nil}

  @max_visual_depth 8

  def render(assigns) do
    visual_level = min(assigns.thread_level, @max_visual_depth)

    assigns
    |> assign(:activity, get_activity(assigns.activity || assigns.comment))
    |> assign(:visual_level, visual_level)
    |> render_sface()
  end

  def get_activity(%{__struct__: Bonfire.Data.Social.Activity, object: %{}} = activity) do
    activity
  end

  def get_activity(%{activity: %{object: %{}} = activity} = replied) do
    activity
    |> Map.put(
      :replied,
      Map.drop(replied, [:activity])
    )
  end

  def get_activity(_), do: nil
end
