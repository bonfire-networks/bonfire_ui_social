defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.Social.Activities

  prop activity, :map
  prop object, :map

  # TODO: put in config and/or autogenerate with Verbs genserver
  @reply_verbs ["reply","respond"]
  @create_verbs ["create"] ++ @reply_verbs
  @react_verbs ["like", "boost", "flag"]

  def update(%{activity: %{} = activity} = assigns, socket) do

    # IO.inspect(assigns, label: "ActivityLive assigns")

    activity = activity
                |> Map.put(:object, e(assigns, :object, object(activity)))
                # |> IO.inspect(label: "ActivityLive activity")


    verb = e(activity, :verb, :verb, "create") |> verb_maybe_modify(activity) #|> IO.inspect

    components = (
      component_activity_subject(verb, activity, assigns)
      ++ component_maybe_reply_to(verb, activity, e(assigns, :showing_within_thread, nil))
      ++ component_object(verb, activity)
      ++ component_actions(verb, activity, assigns)
    ) |> Enum.filter(& &1)
     # |> IO.inspect(label: "activity components")

    verb_display = verb_display(verb)
    created_verb_display = "create" |> verb_display()

    permalink = path(activity.object)

  {:ok, assign(socket, assigns
    |> assigns_merge(
        object: activity.object,
        date_ago: date_from_now(activity.object),
        activity: activity |> Map.drop([:object]),
        activity_object_components: components,
        verb: verb,
        verb_display: verb_display,
        created_verb_display: created_verb_display,
        permalink: permalink,
        within_feed: true # WIP a boolean for adapting previews based on specific views (Feeds, search results, or other contexts)
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

  # don't show subject twice
  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}, _), do: []
  # quoting a reply_to
  def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]
  # create activities
  def component_activity_subject(verb, %{subject_profile: %{id: _} = profile, subject_character: %{id: _} = character}, _) when verb in @create_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]
  def component_activity_subject(verb, %{subject_profile: %{id: _} = profile}, _) when verb in @create_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: nil}}]
  def component_activity_subject(verb, %{subject_character: %{id: _} = character}, _) when verb in @create_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: nil, character: character}}]
  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, _) when verb in @react_verbs, do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  def component_activity_subject(verb, activity, _), do: [component_activity_maybe_creator(activity)]


  def component_activity_maybe_creator(%{object_created: %{
    creator_profile: %{id: _} = profile,
    creator_character: %{id: _} = character
    } = _object_created}), do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}

  def component_activity_maybe_creator(%{creator: %{
    profile: %{id: _} = profile,
    character: %{id: _} = character
    } = _object_creator}), do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}

  def component_activity_maybe_creator(%{provider: _}), do: Bonfire.UI.Social.Activity.ProviderReceiverLive
  def component_activity_maybe_creator(%{primary_accountable: primary_accountable}), do: {Bonfire.UI.Social.Activity.ProviderReceiverLive, %{provider: primary_accountable}}
  def component_activity_maybe_creator(%{receiver: _}), do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{object: %{} = object}), do: component_activity_maybe_creator(object)


  # WIP: subjects didn't showed up for economic activities, I've uncommented this function as temp workaround.
  # def component_activity_maybe_creator(%{subject_character: %{id: _} = character, subject_profile: %{id: _} = profile}), do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}} #|> IO.inspect

  def component_activity_maybe_creator(activity) do
     IO.inspect(no_creation: activity)
     nil
  end

  def component_maybe_reply_to(verb, activity, showing_within_thread \\ nil)

  def component_maybe_reply_to(verb, activity, true), do: []

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
    }, _)
  when verb in @reply_verbs, do: [ # post reply
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      # id: activity_id <> "-reply-post-" <> reply_to_id,
      viewing_main_object: false,
      object: reply_to_post_content,
      activity: %{
        subject_profile: subject_profile,
        subject_character: subject_character,
    }}},
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
  }, _)
  when verb in @reply_verbs and is_binary(reply_to_id), do: [ # other kind of reply, with creator
    {Bonfire.UI.Social.ActivityLive, %{
      activity_inception: true,
      # id: activity_id <> "-reply-" <> reply_to_id,
      viewing_main_object: false,
      object: load_object(e(replied, :reply_to, reply_to_id)),
      activity: %{
        subject_profile: subject_profile,
        subject_character: subject_character,
    }
    }},
  ]

  def component_maybe_reply_to(verb, %{
    id: activity_id,
    replied: %{
      reply_to_id: reply_to_id,
    } = replied
  }, _)
  when verb in @reply_verbs and is_binary(reply_to_id) do # other kind of reply
    reply_to_activity = load_reply_to(e(replied, :reply_to, reply_to_id))

    [
      {Bonfire.UI.Social.ActivityLive, %{
        activity_inception: true,
        # id: activity_id <> "-reply-" <> reply_to_id,
        object: e(reply_to_activity, :object, nil),
        activity: reply_to_activity, #|> IO.inspect,
        viewing_main_object: false
      }},
    ]
  end

  def component_maybe_reply_to(verb, a, _) do
    # IO.inspect(not_reply_verb: verb)
    # IO.inspect(not_reply: a)
    []
  end

  def component_object(_, %{object: %Bonfire.Data.Social.Post{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Social.Message{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %{post_content: %Bonfire.Data.Social.PostContent{}}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Social.PostContent{}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_object(_, %{object: %Bonfire.Data.Identity.User{}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_object(_, %{object: %{} = object}) do
    case Bonfire.Common.Types.object_type(object) do
      type ->
        component_for_object_type(type)

      _ ->
        # IO.inspect(component_object_type_unrecognised: object)
        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, activity) do
    # IO.inspect(component_object_unknown: activity)
    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_for_object_type(type) when type in [ValueFlows.EconomicEvent], do: [Bonfire.UI.Social.Activity.EconomicEventLive]
  def component_for_object_type(type) when type in [ValueFlows.EconomicResource], do: [Bonfire.UI.Social.Activity.EconomicResourceLive]
  def component_for_object_type(type) when type in [ValueFlows.Planning.Intent], do: [Bonfire.UI.Social.Activity.IntentTaskLive] # TODO: choose between Task and other Intent types
  # def component_for_object_type(type) when type in [ValueFlows.Process], do: [Bonfire.UI.Social.Activity.ProcessListLive] # TODO: choose between Task and other Intent types
  def component_for_object_type(type) when type in [ValueFlows.Process], do: [Bonfire.Common.Config.get([:ui, :default_instance_feed_previews, :process], Bonfire.UI.Social.Activity.ProcessListLive)]
  def component_for_object_type(type) do
    # IO.inspect(component_object_type_unknown: type)
    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_actions(_, _, %{activity_inception: true}), do: []
  def component_actions(_, %{object: %{} = object}, _) do
    case Bonfire.Common.Types.object_type(object) do
      type ->
        actions_for_object_type(object, type)

      _ ->
        # IO.inspect(component_object_type_unrecognised: object)
        [Bonfire.UI.Social.Activity.NoActionsLive]
    end
  end
  def component_actions(_, _, _), do: []

  # WIP: Customize actions for each activity type
  def actions_for_object_type(object, type) when type in [Bonfire.Data.Social.Post, Bonfire.Data.Social.PostContent], do: component_show_standard_actions(object)
  def actions_for_object_type(object, type) when type in [ValueFlows.EconomicEvent], do: component_show_event_actions(object)
  def actions_for_object_type(object, type) when type in [ValueFlows.EconomicResource], do: component_show_process_actions(object)
  def actions_for_object_type(object, type) when type in [ValueFlows.Planning.Intent], do: component_show_process_actions(object)# TODO: choose between Task and other Intent types
  def actions_for_object_type(object, type) when type in [ValueFlows.Process], do: component_show_process_actions(object) # TODO: choose between Task and other Intent types
  def actions_for_object_type(object, type) do
    # IO.inspect(component_object_type_unknown: type)
    component_show_standard_actions(object)
    # [Bonfire.UI.Social.Activity.NoActionsLive]
  end

  # TODO: make which object have actions configurable
  def component_actions(_, %{object: %{id: _} = object}, _), do: object |> component_show_standard_actions
  def component_actions(_, _, _), do: []

  def component_show_standard_actions(object), do: [{Bonfire.UI.Social.Activity.ActionsLive, %{object: object}}]
  def component_show_process_actions(object), do: [{Bonfire.UI.Social.Activity.ProcessActionsLive, %{object: object}}]
  def component_show_event_actions(object) do
    [{Bonfire.UI.Social.Activity.EventActionsLive, %{object: e(object, :resource_inventoried_as, "")}}]
  end


  def object(%{object: %{post_content: %{id: _} = _content} = object}), do: object # no need to load Post object
  def object(%{object: %Pointers.Pointer{id: _} = object}), do: load_object(object) # get other pointable objects (only as fallback, should normally already be preloaded)
  def object(%{object: %{id: _} = object}), do: object # any other preloaded object
  def object(%{object_id: id}), do: load_object(id) # last fallback, load any non-preloaded pointable object
  def object(activity), do: activity


  def load_reply_to(reply_to) do
    object = load_object(reply_to)

    %{
      object: object,
      subject_profile: e(object, :created, :creator_profile, nil),
      subject_character: e(object, :created, :creator_character, nil)
    }
  end

  def load_object(id_or_pointer) do
    with {:ok, obj} <- Bonfire.Common.Pointers.get(id_or_pointer)
      # |> IO.inspect
      # TODO: avoid so many queries
      |> repo().maybe_preload([:post_content])
      |> repo().maybe_preload([created: [:creator_profile, :creator_character]])
      |> repo().maybe_preload([:profile, :character]) do
        obj
      else
        # {:ok, obj} -> obj
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
  def verb_maybe_modify("create", %{object: %{action: %{label: label}} = _economic_event}), do: label
  def verb_maybe_modify("create", %{object: %{action: %{id: id}} = _economic_event}), do: id
  def verb_maybe_modify("create", %{object: %{action_id: label} = _economic_event}) when is_binary(label), do: label
  def verb_maybe_modify("create", %{object: %{action: label} = _economic_event}) when is_binary(label), do: label
  def verb_maybe_modify(verb, _), do: verb

  def verb_display(verb) do
    verb
      |> Verbs.conjugate(tense: "past", person: "third", plurality: "plural")
  end

  # def reply_to_display(%Pointers.Pointer{} = reply_to) do
  #   Bonfire.Common.Pointers.get!(reply_to)
  #   |> repo().maybe_preload([:post_content])
  #   |> repo().maybe_preload([:profile, :character])
  #   |> reply_to_display()
  # end
  # def reply_to_display(%{post_content: post_content} = _post), do: post_content |> reply_to_display()
  # def reply_to_display(%{profile: profile, character: character}), do: Map.merge(profile, character) |> reply_to_display()

  # def reply_to_display(%{name: name} = reply_to) when is_binary(name) and name !="", do: "commented on " <> object_link(name, reply_to)
  # def reply_to_display(%{summary: summary} = reply_to) when is_binary(summary) and summary !="", do: "responded to " <> object_link(summary, reply_to)
  # def reply_to_display(%{html_body: html_body} = reply_to), do: "responded to " <> object_link(html_body, reply_to, "hover:underline italic")

  # # TODO: use live_redirect
  # def object_link(text, %{character: %{username: username}}, class \\ "hover:underline font-bold"), do: "<a class='#{class}' href='/user/#{username}'>#{text}</a>"
  # def object_link(text, %{id: id}, class), do: "<a class='#{class}' href='/discussion/#{id}'>#{text}</a>"

  def activity_component(component, assigns, socket) do
    case component do

    {module, %{} = component_assigns} when is_atom(module) ->
      live_component(
        socket,
        module,
        assigns_clean(
          assigns
          |> assigns_merge(component_assigns)
        )
      )

    module when is_atom(module) ->
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
  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
