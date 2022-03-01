defmodule Bonfire.UI.Social.CommentLive do
  use Bonfire.Web, :stateless_component
  alias Bonfire.UI.Social.CommentLive

  prop comment, :map
  prop activity, :map, default: %{}
  prop object, :map, default: %{}
  prop thread_level, :any
  prop child_replies, :any
  prop thread_id, :any
  prop sub_replies_count, :integer, default: 0
  prop url, :string

  def activity(%{__struct__: Bonfire.Data.Social.Activity} = activity) do
    activity
  end

  def activity(%{activity: activity}) do
    activity
  end

  def sub_replies_count(comment) do
    activity = activity(comment)
    e(activity, :replied, :nested_replies_count, 0) + e(activity, :replied, :direct_replies_count, 0)
  end

end
