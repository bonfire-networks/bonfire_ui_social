defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :stateless_component

  alias Bonfire.Social.Activities
  require Logger

  prop activity, :map
  prop object, :any
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :any, default: :feed
  prop hide_reply, :boolean, default: false

  # TODO: put in config and/or autogenerate with Verbs genserver
  @reply_verbs ["reply","respond"]
  @create_verbs ["create"]
  @react_verbs ["like", "boost", "flag"]
  @create_or_reply_verbs @create_verbs ++ @reply_verbs

  def render(%{activity: %{} = activity} = assigns) do

    # Logger.info("ActivityLive: activity provided")

    #IO.inspect(assigns, label: "ActivityLive initial assigns")

    activity = activity
                |> Map.put(:object, e(assigns, :object, nil) || Activities.object_from_activity(activity))
                # |> IO.inspect(label: "ActivityLive activity")

    verb = e(activity, :verb, :verb, "create")
            |> verb_maybe_modify(activity)
            #|> IO.inspect
    verb_display = verb_display(verb)
    created_verb_display = "create" |> verb_display()

    permalink = path(activity.object)

    components = (
      component_activity_subject(verb, activity, assigns)
      ++ component_maybe_reply_to(verb, activity, e(assigns, :showing_within, nil))
      ++ component_object(verb, activity)
      ++ component_actions(verb, activity, assigns)
    )
    |> Enum.filter(& &1)
    |> Enum.map(fn
      c when is_atom(c) -> {c, nil}
      other -> other
    end)
    # |> IO.inspect(label: "ActivityLive: activity_object_components")

  assigns = assigns
    |> assigns_merge(
        object: activity.object,
        object_id: e(activity.object, :id, "no-object"),
        date_ago: date_from_now(activity.object),
        activity: activity |> Map.drop([:object]),
        activity_object_components: components,
        verb: verb,
        verb_display: verb_display,
        created_verb_display: created_verb_display,
        permalink: permalink
      )
    |> Map.new
    #|> IO.inspect(label: "ActivityLive final assigns")


    ~F"""
    <div
      class={
      "activity p-3 relative pl-16",
      "showing_within:feed": e(assigns, :showing_within, nil) == :feed,
      "main_reply_to mb-2 p-2 mt-2 relative border-l-4 border-l-base-300 border border-base-200 rounded-sm bg-base-300 bg-opacity-20": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) == nil and e(@activity, :id, nil) == nil, # showing a quoted reply_to
      "showing_within:thread": e(assigns, :showing_within, nil) == :thread,
      "showing_within:notifications": e(assigns, :showing_within, nil) == :notifications,
      "reply": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) != nil and e(@activity, :id, nil) != nil,
      }>
      {#for {component, component_assigns} when is_atom(component) <- e(assigns, :activity_object_components, [])}
        <Surface.Components.Dynamic.Component
          module={component}
          activity={e(component_assigns, :activity, @activity)}
          object={e(component_assigns, :object, @object)}
          object_id={e(component_assigns, :object_id, @object_id)}
          date_ago={e(component_assigns, :date_ago, @date_ago)}
          verb={e(component_assigns, :verb, @verb)}
          verb_display={e(component_assigns, :verb_display, @verb_display)}
          permalink={e(component_assigns, :permalink, @permalink)}
          viewing_main_object={e(component_assigns, :viewing_main_object, e(assigns, :viewing_main_object, false))}
          hide_reply={e(component_assigns, :hide_reply, e(assigns, :hide_reply, false))}
          created_verb_display={@created_verb_display}
          showing_within={e(assigns, :showing_within, :feed)}
          profile={e(component_assigns, :profile, nil)}
          character={e(component_assigns, :character, nil)}
        />
      {/for}
    </div>
    """
  end

  def render(assigns) do

    Logger.warn("ActivityLive: No activity provided")

    ~F"""

    """
  end

  # don't show subject twice
  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}, _), do: []
  # quoting a reply_to
  def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]
  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, _) when verb in @react_verbs, do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}, component_activity_maybe_creator(activity)]
  # replies (when shown in notifications)
  def component_activity_subject(verb, activity, %{showing_within: :notifications}) when verb in @reply_verbs, do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}]
  # create (or reply) activities
  def component_activity_subject(verb, %{subject: %{profile: %{id: _} = profile, character: %{id: _} = character}}, _) when verb in @create_or_reply_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]
  def component_activity_subject(verb, %{subject: %{profile: %{id: _} = profile}}, _) when verb in @create_or_reply_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: nil}}]
  def component_activity_subject(verb, %{subject: %{character: %{id: _} = character}}, _) when verb in @create_or_reply_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: nil, character: character}}]
  # other
  def component_activity_subject(verb, activity, _), do: [component_activity_maybe_creator(activity)]


  def component_activity_maybe_creator(%{created: %{
    creator_profile: %{id: _} = profile,
    creator_character: %{id: _} = character
    }}), do: component_activity_maybe_creator(%{profile: profile, character: character})

  def component_activity_maybe_creator(%{
    profile: %{id: _} = profile,
    character: %{id: _} = character
    } = _creator), do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}

  def component_activity_maybe_creator(%{creator: %{
    profile: %{id: _} = profile,
    character: %{id: _} = character
    } = creator}), do: component_activity_maybe_creator(creator)

  def component_activity_maybe_creator(%{provider: %{id: _}}), do: Bonfire.UI.Social.Activity.ProviderReceiverLive
  def component_activity_maybe_creator(%{primary_accountable: %{id: _} = primary_accountable}), do: {Bonfire.UI.Social.Activity.ProviderReceiverLive, %{provider: primary_accountable}}
  def component_activity_maybe_creator(%{receiver: %{id: _}}), do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{created: _created} = object), do: object |> repo().maybe_preload(created: [creator: [:profile, :character]]) |> e(:creator, :created, nil) |> component_activity_maybe_creator()
  def component_activity_maybe_creator(%{creator: _} = object), do: object |> repo().maybe_preload(creator: [:profile, :character]) |> e(:creator, nil) |> component_activity_maybe_creator()
  def component_activity_maybe_creator(%{provider: _, receiver: _} = object), do: object |> repo().maybe_preload(provider: [:profile, :character], receiver: [:profile, :character]) |> component_activity_maybe_creator()
  def component_activity_maybe_creator(%{provider: _} = object), do: object |> repo().maybe_preload(provider: [:profile, :character]) |> component_activity_maybe_creator()
  def component_activity_maybe_creator(%{receiver: _} = object), do: object |> repo().maybe_preload(receiver: [:profile, :character]) |> component_activity_maybe_creator()
  def component_activity_maybe_creator(%{primary_accountable: _} = object), do: object |> repo().maybe_preload(primary_accountable: [:profile, :character]) |> component_activity_maybe_creator()

  # FIXME: subjects don't showed up for economic activities, but they do if you uncomment this
  def component_activity_maybe_creator(%{subject: %{character: %{id: _} = character, profile: %{id: _} = profile}}), do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}} #|> IO.inspect

  def component_activity_maybe_creator(%{object: %{} = object}), do: component_activity_maybe_creator(object)

  def component_activity_maybe_creator(activity) do
     Logger.error("ActivityLive: could not find the creator of #{inspect activity}")
     Bonfire.UI.Social.Activity.SubjectLive
  end

  def component_maybe_reply_to(verb, activity, showing_within \\ nil)

  def component_maybe_reply_to(verb, activity, :thread), do: []

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
      object: Activities.load_object(e(replied, :reply_to, reply_to_id)),
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

  def component_object(_, %{object: %{post_content: %Bonfire.Data.Social.PostContent{}}}), do: [Bonfire.UI.Social.Activity.NoteLive]
  # def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]


  def component_object(_, %{object: %{} = object}) do
    case Bonfire.Common.Types.object_type(object) do
      type ->
        Logger.debug("ActivityLive: component object_type recognised: #{inspect(type)}")
        component_for_object_type(type, object)

      _ ->
        Logger.warn("ActivityLive: component object_type NOT recognised: #{inspect(object)}")
        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, activity) do
    Logger.warn("ActivityLive: activity with no object")
    [Bonfire.UI.Social.Activity.UnknownLive]
  end


  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.Post], do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.Message], do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.PostContent], do: [Bonfire.UI.Social.Activity.NoteLive]
  def component_for_object_type(type, object) when type in [Bonfire.Data.Identity.User], do: [Bonfire.UI.Social.Activity.CharacterLive]
  def component_for_object_type(type, object) when type in [Bonfire.Classify.Category], do: [Bonfire.UI.Social.Activity.CategoryLive]
  def component_for_object_type(type, object) when type in [ValueFlows.EconomicEvent], do: [Bonfire.UI.Social.Activity.EconomicEventLive.activity_component(object)]
  def component_for_object_type(type, object) when type in [ValueFlows.EconomicResource], do: [Bonfire.UI.Social.Activity.EconomicResourceLive]
  def component_for_object_type(type, object) when type in [ValueFlows.Planning.Intent], do: [Bonfire.UI.Social.Activity.IntentTaskLive] # TODO: choose between Task and other Intent types
  # def component_for_object_type(type, object) when type in [ValueFlows.Process], do: [Bonfire.UI.Social.Activity.ProcessListLive.activity_component(object)] # TODO: choose between Task and other Intent types
  def component_for_object_type(type, object) when type in [ValueFlows.Process], do: [{Bonfire.Common.Config.get([:ui, :default_instance_feed_previews, :process], Bonfire.UI.Social.Activity.ProcessListLive), object: Bonfire.UI.Social.Activity.ProcessListLive.prepare(object)}]
  def component_for_object_type(type, _object) do
    Logger.warn("ActivityLive: no component available for object_type: #{inspect(type)}, fallback to UnknownLive")
    [{Bonfire.UI.Social.Activity.UnknownLive, %{object_type: type}}]
  end

  def component_actions(_, _, %{activity_inception: true}), do: []
  def component_actions(_, %{object: %{} = object}, _) do
    case Bonfire.Common.Types.object_type(object) do
      type ->
        actions_for_object_type(object, type)

      _ ->
        # Logger.warn("ActivityLive: object NOT recognised: #{object}")
        [Bonfire.UI.Social.Activity.NoActionsLive]
    end
  end
  def component_actions(_, _, _), do: []

  # WIP: Customize actions for each activity type
  def actions_for_object_type(object, type) when type in [Bonfire.Data.Identity.User, Bonfire.Data.Identity.Character], do: []
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





  def load_reply_to(reply_to) do
    object = Activities.load_object(reply_to)

    %{
      object: object,
      subject_profile: e(object, :created, :creator_profile, nil),
      subject_character: e(object, :created, :creator_character, nil)
    }
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


  # def handle_event("like"=action, attrs, socket), do: Bonfire.Social.Likes.live_action(action, attrs, socket)
  # def handle_event(action, attrs, socket), do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
