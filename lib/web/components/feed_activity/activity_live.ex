defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.Web, :stateful_component

  alias Bonfire.Social.Activities
  import Where

  prop(activity, :map)
  prop(object, :any)
  prop(verb_default, :string)
  prop(viewing_main_object, :boolean, default: false)
  prop(showing_within, :any, default: :feed)
  prop(hide_reply, :boolean, default: false)
  prop(class, :string, default: "")

  # TODO: put in config and/or autogenerate with Verbs genserver
  @reply_verbs ["reply", "respond"]
  @create_verbs ["create"]
  @react_verbs ["like", "boost", "flag"]
  @create_or_reply_verbs @create_verbs ++ @reply_verbs

  def render(%{activity: %{} = activity} = assigns) do
    # debug(assigns, "ActivityLive initial assigns")

    activity =
      activity
      # |> debug("Activity provided")
      |> Map.put(:object, object(assigns, activity))

    # |> dump("Activity with object")

    verb =
      Activities.verb_maybe_modify(
        e(activity, :verb, nil) || e(assigns, :verb_default, "create"),
        activity
      )
      |> debug("verb modified")

    verb_display = Activities.verb_display(verb)
    created_verb_display = Activities.verb_display("create")
    object_type = Bonfire.Common.Types.object_type(activity.object) |> debug("object_type")
    # |> String.downcase()
    object_type_readable = module_to_human_readable(object_type)

    thread = e(activity, :replied, :thread, nil) || e(activity, :replied, :thread_id, nil)

    permalink =
      if thread && verb in ["reply", "respond"],
        do: "/discussion/#{ulid(thread)}##{activity.object.id}",
        else: "#{path(activity.object)}#"

    # permalink = path(activity.object)
    components =
      (component_activity_subject(verb, activity, assigns) ++
         (component_maybe_in_reply_to(verb, activity, e(assigns, :showing_within, nil))
          |> debug("component_maybe_in_reply_to")) ++
         component_object(verb, activity, object_type) ++
         component_actions(verb, activity, assigns))
      |> Utils.filter_empty([])
      |> Enum.map(fn
        c when is_atom(c) -> {c, nil}
        other -> other
      end)

    # |> debug("ActivityLive: activity_object_components")

    assigns =
      assigns
      |> assigns_merge(
        object: activity.object,
        object_id: e(activity.object, :id, nil) || e(activity, :id, "no-object-id"),
        object_type: object_type,
        object_type_readable: object_type_readable,
        date_ago: date_from_now(activity),
        activity: activity |> Map.drop([:object]),
        activity_object_components: components,
        verb: verb,
        verb_display: verb_display,
        created_verb_display: created_verb_display,
        permalink: permalink
      )
      |> Map.new()

    # |> debug("ActivityLive final assigns")

    # phx-click="Bonfire.Social.Posts:open_activity"
    # phx-value-id={@permalink}
    # phx-value-showing_within={e(assigns, :showing_within, :feed)}
    # class="cursor-pointer"

    ~F"""
    <article
      id={"activity-"<>(e(@activity, :id, nil) || e(@object, :id, "no-id"))}
      aria-label="user activity"
      role="article"
      tabIndex="0"
      class={
      "p-3 hover:bg-neutral-content hover:bg-opacity-5 activity relative pl-16 " <> @class,
      "main_reply_to mb-2 p-2 mt-2 relative border-l-4 border-l-base-300 border border-base-200 rounded-sm bg-base-300 bg-opacity-50": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) == nil and e(@activity, :id, nil) == nil and e(assigns, :showing_within, nil) != :widget  and e(assigns, :showing_within, nil) != :search, # showing a quoted reply_to
      "reply": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) != nil and e(@activity, :id, nil) != nil,
    }>
      {#for {component, component_assigns} when is_atom(component) <- e(assigns, :activity_object_components, [])}
        <Surface.Components.Dynamic.Component
          module={component}
          id={e(component_assigns, :id, nil)}
          myself={nil}
          activity={e(component_assigns, :activity, @activity)}
          object={e(component_assigns, :object, @object)}
          object_id={e(component_assigns, :object_id, @object_id)}
          object_type={e(component_assigns, :object_type, @object_type)}
          object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
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
          reply_smart_input_text={e(component_assigns, :reply_smart_input_text, nil)}
        />
      {/for}
    </article>
    """
  end

  def render(assigns) do
    warn("ActivityLive: No activity provided")

    ~F"""
    
    """
  end

  def object(assigns, activity) do
    (e(assigns, :object, nil) ||
       Activities.object_from_activity(activity))
    |> repo().maybe_preload(created: [creator: [:profile, :character]])
  end

  # don't show subject twice
  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}, _), do: []

  # quoting a reply_to <-- this is handled by the Bonfire.UI.Social.Activity.SubjectLive internally
  # def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]

  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, _) when verb in @react_verbs,
    do: [
      {Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}},
      component_activity_maybe_creator(activity)
    ]

  # replies (when shown in notifications)
  def component_activity_subject(verb, activity, %{showing_within: :notifications})
      when verb in @reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectMinimalLive, %{verb: verb}}]

  # create (or reply) activities
  def component_activity_subject(
        verb,
        %{subject: %{profile: %{id: _} = profile, character: %{id: _} = character}},
        _
      )
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]

  def component_activity_subject(verb, %{subject: %{profile: %{id: _} = profile}}, _)
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: nil}}]

  def component_activity_subject(verb, %{subject: %{character: %{id: _} = character}}, _)
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: nil, character: character}}]

  # other
  def component_activity_subject(verb, activity, _),
    do: [component_activity_maybe_creator(activity)]

  def component_activity_maybe_creator(%{
        creator_profile: %{id: _} = profile,
        creator_character: %{id: _} = character
      }),
      do: component_activity_maybe_creator(%{profile: profile, character: character})

  def component_activity_maybe_creator(
        %{
          profile: %{id: _} = profile,
          character: %{id: _} = character
        } = _creator
      ),
      do: {Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}

  def component_activity_maybe_creator(%{created: _created} = object),
    do:
      object
      |> repo().maybe_preload(created: [creator: [:profile, :character]])
      |> e(:created, :creator, nil)
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{creator: _} = object),
    do:
      object
      |> repo().maybe_preload(creator: [:profile, :character])
      |> e(:creator, nil)
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{object: %{id: _} = object}),
    do: component_activity_maybe_creator(object)

  def component_activity_maybe_creator(%{subject: %{profile: _, character: _}} = object),
    do:
      object
      |> repo().maybe_preload(subject: [:profile, :character])
      |> e(:subject, nil)
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{provider: %{id: _}}),
    do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{primary_accountable: %{id: _} = primary_accountable}),
    do: {Bonfire.UI.Social.Activity.ProviderReceiverLive, %{provider: primary_accountable}}

  def component_activity_maybe_creator(%{receiver: %{id: _}}),
    do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{provider: _, receiver: _} = object),
    do:
      object
      |> repo().maybe_preload(provider: [:profile, :character], receiver: [:profile, :character])
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{provider: _} = object),
    do:
      object
      |> repo().maybe_preload(provider: [:profile, :character])
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{receiver: _} = object),
    do:
      object
      |> repo().maybe_preload(receiver: [:profile, :character])
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(%{primary_accountable: _} = object),
    do:
      object
      |> repo().maybe_preload(primary_accountable: [:profile, :character])
      |> component_activity_maybe_creator()

  def component_activity_maybe_creator(activity) do
    error("ActivityLive: could not find the creator of #{inspect(activity)}")
    nil
  end

  def component_maybe_in_reply_to(verb, activity, showing_within \\ nil)
  def component_maybe_in_reply_to(verb, activity, :thread), do: []
  def component_maybe_in_reply_to(verb, activity, :create_activity_form), do: []

  def component_maybe_in_reply_to(
        verb,
        %{
          reply_to: %{
            post_content: %{id: id} = reply_to_post_content,
            created: %{
              creator: %{
                character: %{id: _} = subject_character,
                profile: %{id: _} = subject_profile
              }
            }
          }
        },
        _
      )
      # reply with post_content
      when verb in @reply_verbs,
      do: [
        {Bonfire.UI.Social.ActivityLive,
         %{
           id: "ra:" <> id,
           activity_inception: true,
           viewing_main_object: false,
           object: reply_to_post_content,
           activity: %{
             subject: %{
               profile: subject_profile,
               character: subject_character
             }
           }
         }}
      ]

  def component_maybe_in_reply_to(
        verb,
        %{
          reply_to:
            %{
              id: reply_to_id,
              created: %{
                character: %{id: _} = subject_character,
                profile: %{id: _} = subject_profile
              }
            } = replied
        },
        _
      )
      # other kind of reply, with creator
      when verb in @reply_verbs and is_binary(reply_to_id),
      do: [
        {Bonfire.UI.Social.ActivityLive,
         %{
           id: "ra:" <> reply_to_id,
           activity_inception: true,
           viewing_main_object: false,
           object: Activities.load_object(replied),
           activity: %{
             subject: %{
               profile: subject_profile,
               character: subject_character
             }
           }
         }}
      ]

  def component_maybe_in_reply_to(
        verb,
        %{
          reply_to:
            %{
              id: reply_to_id
            } = replied
        },
        _
      )
      # other kind of reply
      when verb in @reply_verbs and is_binary(reply_to_id) do
    reply_to_activity = load_reply_to(e(replied, reply_to_id))

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "ra:" <> reply_to_id,
         activity_inception: true,
         object: e(reply_to_activity, :object, nil),
         # |> IO.inspect,
         activity: reply_to_activity |> Map.delete(:object),
         viewing_main_object: false
       }}
    ]
  end

  def component_maybe_in_reply_to(verb, %{replied: %{} = replied}, showing_within),
    do: component_maybe_in_reply_to(verb, replied, showing_within)

  def component_maybe_in_reply_to(_, a, _) do
    # debug(a, "ActivityLive: no reply_to")
    []
  end

  def component_object(_, %{object: %{post_content: %Bonfire.Data.Social.PostContent{}}}, _),
    do: [Bonfire.UI.Social.Activity.NoteLive]

  # def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_object(_, %{object: %{} = object}, object_type) do
    case object_type do
      type when is_atom(type) ->
        debug("ActivityLive: component object_type recognised: #{inspect(type)}")
        component_for_object_type(type, object)

      _ ->
        warn("ActivityLive: component object_type NOT detected: #{inspect(object)}")
        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, _activity, _) do
    debug("ActivityLive: activity has no object")
    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.Post],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.Message],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.PostContent],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, object) when type in [Bonfire.Data.Identity.User],
    do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_for_object_type(type, object) when type in [Bonfire.Classify.Category],
    do: [Bonfire.UI.Social.Activity.CategoryLive]

  def component_for_object_type(type, object) when type in [ValueFlows.EconomicEvent],
    do: [Bonfire.UI.Social.Activity.EconomicEventLive.activity_component(object)]

  def component_for_object_type(type, object) when type in [ValueFlows.EconomicResource],
    do: [Bonfire.UI.Social.Activity.EconomicResourceLive]

  # TODO: choose between Task and other Intent types
  def component_for_object_type(type, object) when type in [ValueFlows.Planning.Intent],
    do: [Bonfire.UI.Social.Activity.IntentTaskLive]

  # def component_for_object_type(type, object) when type in [ValueFlows.Process], do: [Bonfire.UI.Social.Activity.ProcessListLive.activity_component(object)] # TODO: choose between Task and other Intent types
  def component_for_object_type(type, object) when type in [ValueFlows.Process],
    do: [
      {Bonfire.Common.Config.get(
         [:ui, :default_instance_feed_previews, :process],
         Bonfire.UI.Social.Activity.ProcessListLive
       ), object: Bonfire.UI.Social.Activity.ProcessListLive.prepare(object)}
    ]

  def component_for_object_type(type, _object) do
    warn(
      "ActivityLive: no component set up for object_type: #{inspect(type)}, fallback to UnknownLive"
    )

    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  # WIP: THIS NEEDS TO BE REFACTORED ACCORDING TO actions_for_object_type
  def component_actions("flag", _, _), do: [Bonfire.UI.Social.Activity.FlaggedActionsLive]

  def component_actions(_, _, %{activity_inception: true}), do: []

  def component_actions(_, %{object: %{}} = activity, _) do
    case Bonfire.Common.Types.object_type(activity.object) do
      type ->
        actions_for_object_type(activity, type)

      _ ->
        # warn("ActivityLive: object NOT recognised: #{object}")
        [Bonfire.UI.Social.Activity.NoActionsLive]
    end
  end

  def component_actions(_, _, _), do: []

  # WIP: Customize actions for each activity type
  def actions_for_object_type(activity, type)
      when type in [Bonfire.Data.Identity.User, Bonfire.Data.Identity.Character],
      do: [Bonfire.UI.Social.Activity.MoreActionsLive]

  def actions_for_object_type(activity, type) when type in [Bonfire.Data.Social.Flag], do: []

  def actions_for_object_type(activity, type)
      when type in [Bonfire.Data.Social.Post, Bonfire.Data.Social.PostContent],
      do: component_show_standard_actions(activity)

  def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicEvent],
    do: component_show_event_actions(activity)

  def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicResource],
    do: component_show_process_actions(activity)

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(activity, type) when type in [ValueFlows.Planning.Intent],
    do: component_show_process_actions(activity)

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(activity, type) when type in [ValueFlows.Process],
    do: component_show_process_actions(activity)

  def actions_for_object_type(activity, type) do
    debug(component_object_type_unknown: type)
    component_show_standard_actions(activity)
    # [Bonfire.UI.Social.Activity.NoActionsLive]
  end

  # |> debug
  def component_show_standard_actions(
        %{subject: %{character: %{username: username}}} = _activity
      ),
      do: [{Bonfire.UI.Social.Activity.ActionsLive, %{reply_smart_input_text: "@#{username} "}}]

  def component_show_standard_actions(_activity), do: [Bonfire.UI.Social.Activity.ActionsLive]

  def component_show_process_actions(_activity),
    do: [Bonfire.UI.Social.Activity.ProcessActionsLive]

  def component_show_event_actions(activity) do
    [
      {Bonfire.UI.Social.Activity.EventActionsLive,
       %{object: e(activity, :object, :resource_inventoried_as, "")}}
    ]
  end

  def load_reply_to(reply_to) do
    reply_to = Activities.load_object(reply_to)

    %{
      object: reply_to,
      subject: %{
        profile: e(reply_to, :created, :creator_profile, nil),
        character: e(reply_to, :created, :creator_character, nil)
      }
    }
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

  def handle_event("reply", _, socket) do
    debug("reply!")

    send_update(Bonfire.UI.Social.CreateActivityLive,
      id: :create_activity_form,
      # reply to objects, not activities
      reply_to_id:
        e(socket, :assigns, :object_id, nil) || e(socket, :assigns, :object, :id, nil) ||
          e(socket, :assigns, :activity, :object, :id, nil),
      # thread_id: activity_id,
      activity: e(socket, :assigns, :activity, nil),
      object: e(socket, :assigns, :object, nil)
    )

    {:noreply, socket}
  end

  def handle_event(action, attrs, socket),
    do: Bonfire.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
