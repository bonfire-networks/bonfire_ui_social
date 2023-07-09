defmodule Bonfire.UI.Social.CommentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Social.CommentLive

  prop comment, :map
  prop activity, :any, default: nil
  # prop object, :any, default: nil
  prop thread_object, :any
  prop thread_level, :any
  prop child_replies, :any
  prop thread_id, :any
  prop feed_id, :any, default: nil
  prop sub_replies_count, :integer, default: 0
  prop thread_mode, :any, default: nil
  prop showing_within, :atom, default: :thread
  # prop page, :any, default: "thread"
  # prop create_object_type, :any, default: nil
  prop current_url, :string, default: nil

  def get_activity(%{__struct__: Bonfire.Data.Social.Activity, object: %{}} = activity) do
    activity
  end

  def get_activity(%{activity: %{object: %{}} = activity}) do
    activity
  end

  def get_activity(_), do: nil

  def sub_replies_count(comment) do
    activity = get_activity(comment)

    e(activity, :replied, :nested_replies_count, 0) +
      e(activity, :replied, :direct_replies_count, 0)
  end
end
