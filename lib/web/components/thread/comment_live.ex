defmodule Bonfire.UI.Social.CommentLive do
  use Bonfire.Web, :stateless_component
  alias Bonfire.UI.Social.CommentLive

  prop comment, :map
  prop thread_level, :any
  prop child_replies, :any
  prop reply_to_thread_id, :any

  def update(%{comment: %{__struct__: Bonfire.Data.Social.Activity} = activity} = assigns, socket) do

    # {activity, comment} = Map.pop(comment, :activity)
    # IO.inspect(activity)
    {object, activity} = Map.pop(activity, :object)

    {:ok, assign(socket, assigns
      |> assigns_merge(prepare(activity, object, activity))
    )}
  end

  def update(%{comment: comment} = assigns, socket) do

    # IO.inspect(comment)
    {activity, comment} = Map.pop(comment, :activity)
    # IO.inspect(activity)
    {object, activity} = Map.pop(activity, :object)

    {:ok, assign(socket, assigns
      |> assigns_merge(prepare(comment, object, activity))
    )}
  end

  def prepare(comment, object, activity) do
    %{
      activity: activity,
      object: object,
      comment: comment,
      sub_replies_count: e(activity, :replied, :nested_replies_count, 0) + e(activity, :replied, :direct_replies_count, 0),
      date_ago: date_from_now(comment)
    }
  end

end
