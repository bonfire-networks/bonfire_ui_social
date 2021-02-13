defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    activity = assigns.activity
    |> IO.inspect
    # |> repo().maybe_preload(:object)
    # |> repo().maybe_preload([object: [:profile, :character]])
    # |> repo().maybe_preload([object: [:post_content]])

    object = object(activity)
    # |> IO.inspect

    verb = e(activity, :verb, :verb, "post")

    verb_display = verb_display(verb, activity, object)
    created_display = verb_display("create", activity, object)

    components = component_activity_subject(verb, activity, object)
    # ++ component_object_subject(verb, activity, object)
    ++ component_object(verb, activity, object)
    ++ component_actions(verb, activity, object)

    assigns = assigns
    |> Map.merge(%{
        activity: activity,
        object: object,
        activity_object_components: components,
        date_ago: date_from_now(object),
        verb_display: verb_display,
        created_verb_display: created_display
      })
    # |> IO.inspect

    {:ok, assign(socket, assigns) }
  end

  def component_activity_subject("like", _, _), do: [Bonfire.UI.Social.Activity.SubjectMinimalLive, Bonfire.UI.Social.Activity.CreatorLive]
  def component_activity_subject(_, _, %Bonfire.Data.Identity.User{}), do: []
  def component_activity_subject(_, _, _), do: [Bonfire.UI.Social.Activity.SubjectLive]

  def component_object(_, _, %Bonfire.Data.Social.Post{}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, _, %Bonfire.Data.Identity.User{}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  def component_object(_, _, _), do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_actions(_, _, %Bonfire.Data.Social.Post{}), do: [Bonfire.UI.Social.Activity.ActionsLive]
  def component_actions(_, _, _), do: [Bonfire.UI.Social.Activity.NoActionsLive]

  def object(%{object_post: %{id: _} = object}), do: object
  def object(%{object: %Pointers.Pointer{id: _} = object}) do
    Bonfire.Common.Pointers.get!(object)
    # |> repo().maybe_preload([creator: [:creator_user]])
    |> repo().maybe_preload([:profile, :character])
  end
  def object(%{object: %{id: _} = object}), do: object
  def object(%{object_id: id}), do: Bonfire.Common.Pointers.get!(id)

  def verb_display(verb, activity, object) do
    verb
      |> Verbs.conjugate(tense: "past", person: "third", plurality: "plural")
      |> verb_maybe_modify(activity, object)
  end

  def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to}, %Bonfire.Data.Social.Post{}), do: "commented on " <> reply_to_display(reply_to)
  def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to}, _), do: "responded to " <> reply_to_display(reply_to)
  def verb_maybe_modify("created", _, %Bonfire.Data.Social.Post{}), do: "wrote"
  def verb_maybe_modify(verb, _, _), do: verb

  def reply_to_display(%Pointers.Pointer{} = reply_to) do
    Bonfire.Common.Pointers.get!(reply_to)
    |> repo().maybe_preload([:post_content])
    |> repo().maybe_preload([:profile, :character])
    |> reply_to_display()
  end
  def reply_to_display(%{post_content: post_content} = _post), do: post_content |> reply_to_display()
  def reply_to_display(%{profile: profile, character: character}), do: Map.merge(profile, character) |> reply_to_display()
  def reply_to_display(%{name: name} = reply_to) when is_binary(name) and name !="", do: name |> reply_to_link(reply_to)
  def reply_to_display(%{summary: summary} = reply_to) when is_binary(summary) and summary !="", do: summary |> reply_to_link(reply_to)
  def reply_to_display(%{html_body: html_body} = reply_to), do: html_body |> reply_to_link(reply_to)

  # TODO: use live_redirect
  def reply_to_link(text, %{character: %{username: username}}), do: "<a class='hover:underline font-bold' href='/user/#{username}'>#{text}</a>"
  def reply_to_link(text, %{id: id}), do: "<a class='hover:underline font-bold' href='/discussion/#{id}'>#{text}</a>"

  def handle_event("like"=action, attrs, socket), do: Bonfire.Me.Social.Likes.live_action(action, attrs, socket)

end
