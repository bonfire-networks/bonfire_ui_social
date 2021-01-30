defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    activity = assigns.activity
    |> repo().maybe_preload(:object)
    |> repo().maybe_preload([object: [:profile, :character]])
    |> repo().maybe_preload([object: [:post_content]])

    assigns = assigns
    |> Map.merge(%{
        activity: activity,
        activity_object_component: activity_object_component(activity),
        date_ago: date_ago(activity.id)
      })
    |> IO.inspect

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

end
