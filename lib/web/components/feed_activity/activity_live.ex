defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration

  def update(assigns, socket) do

    assigns = if is_map(assigns.activity) do
      activity = %{assigns.activity | object: object(assigns.activity)}
      # |> IO.inspect
      # |> repo().maybe_preload(:object)
      # |> repo().maybe_preload([object: [:profile, :character]])
      # |> repo().maybe_preload([object: [:post_content]])

      verb = e(activity, :verb, :verb, "post") |> verb_maybe_modify(activity)

      components = component_activity_subject(verb, activity)
      # ++ component_object_subject(verb, activity)
      ++ component_object(verb, activity)
      ++ component_actions(verb, activity, assigns)

      verb_display = verb_display(verb, activity)
      created_verb_display = "create" |> verb_maybe_modify(activity) |> verb_display(activity)

      permalink = permalink(assigns, activity)

      assigns
      |> assigns_merge(%{
          activity: activity,
          activity_object_components: components |> Enum.filter(& &1),
          date_ago: date_from_now(activity.object),
          verb: verb,
          verb_display: verb_display,
          created_verb_display: created_verb_display,
          permalink: permalink
        })

    else
      assigns
      |> assigns_merge(%{
          activity: nil,
          activity_object_components: [],
          date_ago: nil,
          verb: "",
          verb_display: "",
          created_verb_display: "",
          permalink: ""
        })
    end

    {:ok, assign(socket, assigns) }
  end


  # def permalink(%{reply_to_thread_id: reply_to_thread_id}, %{object: %{id: id}}) do
  #   "/discussion/"<>reply_to_thread_id<>"/reply/"<>id
  # end
  def permalink(_, %{object: %{id: id}}) do
    "/discussion/"<>id
  end
  def permalink(_, %{object_id: id}) do
    "/discussion/"<>id
  end

  def component_activity_subject("like"=verb, activity), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject("boost"=verb, activity), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject("flag"=verb, activity), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]

  def component_activity_subject(verb,
    %{
      id: activity_id,
      reply_to_post_content: %{id: reply_id} = reply_to_post_content,
      reply_to_creator_character: %{id: _} = reply_to_creator_character,
      reply_to_creator_profile: %{id: _} = reply_to_creator_profile
    } )
  when verb in ["reply","respond"], do: [ # post reply
    {Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}},
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      id: activity_id <> reply_id,
      activity: %{
        object: reply_to_post_content,
        object_post_content: reply_to_post_content, # TODO: avoid data duplication
        subject_profile: reply_to_creator_profile,
        subject_character: reply_to_creator_character,
        viewing_main_object: false
    }}},
    Bonfire.UI.Social.Activity.SubjectLive]

  def component_activity_subject(verb, %{
    id: activity_id,
    reply_to: %{id: reply_id} = reply_to
  })
  when verb in ["reply","respond"], do: [ # other kind of reply
    {Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}},
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      id: activity_id <> reply_id,
      activity: load_reply_to(reply_to),
      viewing_main_object: false
    }},
    Bonfire.UI.Social.Activity.SubjectLive]

  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}), do: []

  def component_activity_subject(_, _), do: [Bonfire.UI.Social.Activity.SubjectLive]

  def component_activity_maybe_creator(%{object_creator_profile: %{id: _}}), do: Bonfire.UI.Social.Activity.CreatorLive
  def component_activity_maybe_creator(_), do: nil


  def component_object(_, %{object: %Bonfire.Data.Social.Post{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object_post_content: %{id: _}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Identity.User{}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  def component_object(_, _), do: [Bonfire.UI.Social.Activity.NoteLive] # TODO: fallback for unknown objects


  def component_actions(_, _, %{activity_inception: true}), do: []
  def component_actions(_, %{object_post_content: %{id: _} = object}, _), do: component_show_actions(object)
  def component_actions(_, %{object: %Bonfire.Data.Social.Post{} = object}, _), do: component_show_actions(object) # TODO: make which object have actions configurable
  def component_actions(_, _, _), do: []

  def component_show_actions(object), do: [{Bonfire.UI.Social.Activity.ActionsLive, %{object: object}}]

  def object(%{object_post_content: %{id: _} = object}), do: object # posts are already preloaded in query
  def object(%{object: %Pointers.Pointer{id: _} = object}), do: load_object(object) # get other pointable objects
  def object(%{object: %{id: _} = object}), do: object # any other preloaded object
  def object(%{object_id: id}), do: load_object(id) # any non-preloaded pointable object
  def object(_), do: nil

  def load_reply_to(%Pointers.Pointer{} = reply_to) do
    object = load_object(reply_to)

    %{
      object: object,
      subject_profile: e(object, :creator_profile, nil),
      subject_character: e(object, :creator_character, nil)
    }
  end

  def load_object(id_or_pointer) do
    with {:ok, obj} <- Bonfire.Common.Pointers.get(id_or_pointer)
      # TODO: avoid so many queries
      |> repo().maybe_preload([:post_content])
      |> repo().maybe_preload([:creator_profile, :creator_character])
      |> repo().maybe_preload([:profile, :character]) do
        obj
      else _ -> nil
      end
  end

  def verb_maybe_modify("create", %{reply_to_post_content: %{id: _} = reply_to}), do: "reply"
  def verb_maybe_modify("create", %{reply_to: %{id: _} = reply_to}), do: "respond"
  # def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to, object: %Bonfire.Data.Social.Post{}}), do: reply_to_display(reply_to)
  # def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to}), do: reply_to_display(reply_to)
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.PostContent{name: name} = post}), do: "write" #<> object_link(name, post)
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.PostContent{} = _post}), do: "write"
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.Post{} = _post}), do: "write"
  def verb_maybe_modify(verb, _), do: verb

  def verb_display(verb, activity) do
    verb
      |> Verbs.conjugate(tense: "past", person: "third", plurality: "plural")
  end

  def reply_to_display(%Pointers.Pointer{} = reply_to) do
    Bonfire.Common.Pointers.get!(reply_to)
    |> repo().maybe_preload([:post_content])
    |> repo().maybe_preload([:profile, :character])
    |> reply_to_display()
  end
  def reply_to_display(%{post_content: post_content} = _post), do: post_content |> reply_to_display()
  def reply_to_display(%{profile: profile, character: character}), do: Map.merge(profile, character) |> reply_to_display()

  def reply_to_display(%{name: name} = reply_to) when is_binary(name) and name !="", do: "commented on " <> object_link(name, reply_to)
  def reply_to_display(%{summary: summary} = reply_to) when is_binary(summary) and summary !="", do: "responded to " <> object_link(summary, reply_to)
  def reply_to_display(%{html_body: html_body} = reply_to), do: "responded to " <> object_link(html_body, reply_to, "hover:underline italic")

  # TODO: use live_redirect
  def object_link(text, %{character: %{username: username}}, class \\ "hover:underline font-bold"), do: "<a class='#{class}' href='/user/#{username}'>#{text}</a>"
  def object_link(text, %{id: id}, class), do: "<a class='#{class}' href='/discussion/#{id}'>#{text}</a>"


  # def handle_event("like"=action, attrs, socket), do: Bonfire.Social.Likes.live_action(action, attrs, socket)
  defdelegate handle_event(action, attrs, socket), to: Bonfire.Web.LiveHandler

end
