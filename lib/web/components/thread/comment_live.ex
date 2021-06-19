defmodule Bonfire.UI.Social.CommentLive do
  use Bonfire.Web, :live_component


  def update(%{comment: %{__struct__: Bonfire.Data.Social.Activity} = activity} = assigns, socket) do

    # IO.inspect(comment)
    # {activity, comment} = Map.pop(comment, :activity)
    # IO.inspect(activity)
    {object, activity} = Map.pop(activity, :object)

    {:ok, assign(socket, assigns
                          |> assigns_merge(prepare(activity, object, activity))
          )
    }
  end

  def update(%{comment: comment} = assigns, socket) do

    # IO.inspect(comment)
    {activity, comment} = Map.pop(comment, :activity)
    # IO.inspect(activity)
    {object, activity} = Map.pop(activity, :object)

    {:ok, assign(socket, assigns
                          |> assigns_merge(prepare(comment, object, activity))
          )
    }
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
