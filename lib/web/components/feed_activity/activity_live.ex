defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :live_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.Social.Activities

  def update(%{activity: %{} = activity} = assigns, socket) do

    activity = activity |> Map.merge(%{object: e(assigns, :object, object(activity))})
    # |> IO.inspect
    # |> repo().maybe_preload(:object)
    # |> repo().maybe_preload([object: [:profile, :character]])
    # |> repo().maybe_preload([object: [:post_content]])

    verb = e(activity, :verb, :verb, "create") |> verb_maybe_modify(activity)

    components = component_activity_subject(verb, activity, assigns)
    ++ component_maybe_reply_to(verb, activity)
    ++ component_object(verb, activity)
    ++ component_actions(verb, activity, assigns)

    verb_display = verb_display(verb)
    created_verb_display = "create" |> verb_maybe_modify(activity) |> verb_display()

    permalink = Activities.permalink(assigns, activity)

  {:ok, assign(socket, assigns
    |> assigns_merge(
        object: activity.object,
        date_ago: date_from_now(activity.object),
        activity: activity |> Map.drop([:object]),
        activity_object_components: components |> Enum.filter(& &1),
        verb: verb,
        verb_display: verb_display,
        created_verb_display: created_verb_display,
        permalink: permalink
      )) }
  end

  def update(assigns, socket) do

    {:ok, assign(socket, assigns
      |> assigns_merge(
          activity: nil,
          activity_object_components: [],
          date_ago: nil,
          verb: "",
          verb_display: "",
          created_verb_display: "",
          permalink: ""
        )) }
  end


  def component_activity_subject("like"=verb, activity, _), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject("boost"=verb, activity, _), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject("flag"=verb, activity, _), do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject("create"=verb, activity, _), do: [component_activity_maybe_creator(activity)]
  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}, _), do: []
  def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]
  def component_activity_subject(_, _, _), do: [Bonfire.UI.Social.Activity.SubjectLive]

  def component_activity_maybe_creator(%{object_created: %{creator_profile: %{id: _}}}), do: Bonfire.UI.Social.Activity.CreatorLive
  def component_activity_maybe_creator(%{object_created: %{creator_character: %{id: _}}}), do: Bonfire.UI.Social.Activity.CreatorLive
  def component_activity_maybe_creator(%{subject_character: _, subject_profile: _}), do: Bonfire.UI.Social.Activity.SubjectLive

  def component_maybe_reply_to(verb,
    %{
      id: activity_id,
      replied: %{
        reply_to_id: reply_to_id,
        reply_to_post_content: %{id: _} = reply_to_post_content,
        reply_to_created: %{
          creator_character: %{id: _} = subject_character,
          creator_profile: %{id: _} = subject_profile
        }
      }
    } )
  when verb in ["reply","respond"], do: [ # post reply
    # {Bonfire.UI.Social.Activity.SubjectLive, %{verb: verb}},
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      # id: activity_id <> "-reply-post-" <> reply_to_id,
      viewing_main_object: false,
      activity: %{
        object: reply_to_post_content,
        # object_post_content: reply_to_post_content,
        subject_profile: subject_profile,
        subject_character: subject_character,
    }}},
    # Bonfire.UI.Social.Activity.SubjectLive
  ]

  def component_maybe_reply_to(verb, %{
    id: activity_id,
    replied: %{
      reply_to_id: reply_to_id,
      reply_to_created: %{
        creator_character: %{id: _} = subject_character,
        creator_profile: %{id: _} = subject_profile
      }
    } = replied
  })
  when verb in ["reply","respond"] and is_binary(reply_to_id), do: [ # other kind of reply, with creator
    # {Bonfire.UI.Social.Activity.SubjectLive, %{verb: verb}},
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      # id: activity_id <> "-reply-" <> reply_to_id,
      viewing_main_object: false,
      activity: %{
        object: load_object(e(replied, :reply_to, reply_to_id)),
        subject_profile: subject_profile,
        subject_character: subject_character,
    }
    }},
    # Bonfire.UI.Social.Activity.SubjectLive
  ]

  def component_maybe_reply_to(verb, %{
    id: activity_id,
    replied: %{
      reply_to_id: reply_to_id,
    } = replied
  })
  when verb in ["reply","respond"] and is_binary(reply_to_id), do: [ # other kind of reply

    # {Bonfire.UI.Social.Activity.SubjectLive, %{verb: verb}},
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      # id: activity_id <> "-reply-" <> reply_to_id,
      activity: load_reply_to(e(replied, :reply_to, reply_to_id)), #|> IO.inspect,
      viewing_main_object: false
    }},
    # Bonfire.UI.Social.Activity.SubjectLive
  ]
  def component_maybe_reply_to(verb, a) do
    # IO.inspect(not_reply_verb: verb)
    # IO.inspect(not_reply: a)
    []
  end

  def component_object(_, %{object: %Bonfire.Data.Social.Post{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Social.PostContent{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object_post_content: %{id: _}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Identity.User{}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]

  if Code.ensure_loaded?(ValueFlows.EconomicEvent) do
    def component_object(_, %{object: %ValueFlows.EconomicEvent{}}), do: [Bonfire.UI.Social.Activity.EconomicEventLive]
    def component_object(_, %{object: %ValueFlows.EconomicResource{}}), do: [Bonfire.UI.Social.Activity.EconomicResourceLive]
  end

  def component_object(_, activity) do
    # IO.inspect(component_object_unknown: activity)
    [Bonfire.UI.Social.Activity.UnknownLive]
  end


  def component_actions(_, _, %{activity_inception: true}), do: []
  def component_actions(_, %{object_post_content: %{id: _} = object}, _), do: component_show_actions(object)
  def component_actions(_, %{object: %Bonfire.Data.Social.Post{} = object}, _), do: component_show_actions(object)
  def component_actions(_, %{object: %Bonfire.Data.Social.PostContent{} = object}, _), do: component_show_actions(object)
  # TODO: make which object have actions configurable
  def component_actions(_, _, _), do: []

  def component_show_actions(object), do: [{Bonfire.UI.Social.Activity.ActionsLive, %{object: object}}]

  def object(%{object_post_content: %{id: _} = object}), do: object # posts are already preloaded in query
  def object(%{object: %{post: %{post_content: %{id: _} = object} = post}}), do: Map.merge(object, post) #|> IO.inspect
  def object(%{object: %{post_content: %{id: _} = object}}), do: object
  def object(%{object: %Pointers.Pointer{id: _} = object}), do: load_object(object) # get other pointable objects
  def object(%{object: %{id: _} = object}), do: object # any other preloaded object
  def object(%{object_id: id}), do: load_object(id) # any non-preloaded pointable object
  def object(_), do: nil


  def load_reply_to(reply_to) do
    object = load_object(reply_to)

    %{
      object: object,
      subject_profile: e(object, :created, :creator_profile, nil),
      subject_character: e(object, :created, :creator_character, nil)
    }
  end

  def load_object(id_or_pointer) do
    with %{id: _} = obj <- Bonfire.Common.Pointers.get(id_or_pointer)
      # |> IO.inspect
      # TODO: avoid so many queries
      |> repo().maybe_preload([:post_content])
      |> repo().maybe_preload([created: [:creator_profile, :creator_character]])
      |> repo().maybe_preload([:profile, :character]) do
        obj
      else
        {:ok, obj} -> obj
        _ -> nil
      end
  end

  def verb_maybe_modify("create", %{replied: %{reply_to_post_content: %{id: _} = _reply_to}}), do: "reply"
  def verb_maybe_modify("create", %{replied: %{reply_to: %{id: _} = _reply_to}}), do: "respond"
  def verb_maybe_modify("create", %{replied: %{reply_to_id: reply_to_id}}) when is_binary(reply_to_id), do: "respond"
  # def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to, object: %Bonfire.Data.Social.Post{}}), do: reply_to_display(reply_to)
  # def verb_maybe_modify("created", %{reply_to: %{id: _} = reply_to}), do: reply_to_display(reply_to)
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.PostContent{name: name} = post}), do: "write" #<> object_link(name, post)
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.PostContent{} = _post}), do: "write"
  def verb_maybe_modify("create", %{object: %Bonfire.Data.Social.Post{} = _post}), do: "write"
  def verb_maybe_modify(verb, _), do: verb

  def verb_display(verb) do
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

  def activity_component(component, assigns, socket) do
    case component do

    {module, %{} = component_assigns} when is_atom(module) ->
      #IO.inspect(activity_module: module)
      #IO.inspect(activity_assign: component_assigns)
      live_component(
        socket,
        module,
        assigns
        |> assigns_merge(component_assigns)
      )

    module when is_atom(module) ->
      #IO.inspect(activity_module: module)
      live_component(
        socket,
        module,
        assigns_clean(assigns)
      )

    string when is_binary(string) ->
      string

    end
  end

  # def handle_event("like"=action, attrs, socket), do: Bonfire.Social.Likes.live_action(action, attrs, socket)
  # def handle_event(action, attrs, socket), do: Bonfire.Web.LiveHandler.handle_event(action, attrs, socket, __MODULE__)

end
