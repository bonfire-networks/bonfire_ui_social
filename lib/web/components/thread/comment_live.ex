defmodule  Bonfire.UI.Social.CommentLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

    {activity, comment} = Map.pop(assigns.comment, :activity)

    {:ok, assign(socket, assigns
    # |> IO.inspect
    |> assigns_merge(%{
      activity: activity,
      comment: comment,
      sub_replies_count: e(activity, :replied, :nested_replies_count, 0) + e(activity, :replied, :direct_replies_count, 0),
      date_ago: date_from_now(assigns.comment),
      })) }
  end


end
