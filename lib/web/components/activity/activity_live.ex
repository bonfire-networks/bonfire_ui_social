defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    activity = assigns.activity
    # |> IO.inspect
    # |> repo().maybe_preload(:object)
    # |> repo().maybe_preload([object: [:profile, :character]])
    # |> repo().maybe_preload([object: [:post_content]])

    object = object(activity)
    |> IO.inspect

    verb_display = e(activity, :verb, :verb, "post")
      |> Verbs.conjugate(tense: "past", person: "third", plurality: "plural")
      |> verb(activity, object)

    assigns = assigns
    |> Map.merge(%{
        activity: activity,
        object: object,
        activity_object_component: object_live_component(activity, object),
        date_ago: date_ago(activity.id),
        verb_display: verb_display
      })
    # |> IO.inspect

    {:ok, assign(socket, assigns) }
  end

  def verb("created", %{reply_to: %{id: _}}, %Bonfire.Data.Social.Post{}), do: "commented on"
  def verb("created", _, %Bonfire.Data.Social.Post{}), do: "wrote"
  def verb("created", %{reply_to: %{id: _}}, _), do: "reacted to"
  def verb(verb, _, _), do: verb

  def object_live_component(_, %Bonfire.Data.Identity.User{}), do: Bonfire.UI.Social.Activity.CharacterLive
  def object_live_component(_, _), do: Bonfire.UI.Social.Activity.NoteLive


  def date_ago(id) do
    with {:ok, ts} <- Pointers.ULID.timestamp(id) do
      date_from_now(ts)
    end
  end

  def object(%{object_post: %{id: _} = object}), do: object
  def object(%{object: %Pointers.Pointer{id: _} = object}), do: Bonfire.Common.Pointers.get!(object)
  def object(%{object: %{id: _} = object}), do: object


  def handle_event("like"=action, attrs, socket), do: Bonfire.Me.Social.Likes.live_action(action, attrs, socket)

end
