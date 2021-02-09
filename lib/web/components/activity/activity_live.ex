defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    activity = assigns.activity
    # |> repo().maybe_preload(:object)
    # |> repo().maybe_preload([object: [:profile, :character]])
    # |> repo().maybe_preload([object: [:post_content]])

    object = activity_object(activity)

    assigns = assigns
    |> Map.merge(%{
        activity: activity,
        object: object,
        activity_object_component: activity_object_component(activity),
        date_ago: date_ago(activity.id)
      })
    # |> IO.inspect

    {:ok, assign(socket, assigns) }
  end

  def activity_object_component(activity) do
    case activity.object do
      %Bonfire.Data.Identity.User{} -> Bonfire.UI.Social.Activity.CharacterLive
      _ -> Bonfire.UI.Social.Activity.NoteLive
    end
  end

  def date_ago(id) do
    with {:ok, ts} <- Pointers.ULID.timestamp(id) do
      ts
      # TODO: make it nice
    end
  end

  def activity_object(activity) do
    e(activity, :object_post, e(activity, :object, nil))
  end

  def handle_event("like-"<>_ = action, attrs, socket), do: Bonfire.Me.Social.Likes.live_action(action, attrs, socket)

end
