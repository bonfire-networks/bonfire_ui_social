defmodule  Bonfire.UI.Social.CommentLive do
  use Bonfire.Web, :live_component

  def update(assigns, socket) do

    {activity, comment} = Map.pop(assigns.comment, :activity)
    {object, activity} = Map.pop(activity, :object_post_content)

    {:ok, assign(socket, assigns
    |> assigns_merge(
      activity: activity,
      object: object,
      comment: comment,
      sub_replies_count: e(activity, :replied, :nested_replies_count, 0) + e(activity, :replied, :direct_replies_count, 0),
      date_ago: date_from_now(assigns.comment),
      )) }
  end


end
