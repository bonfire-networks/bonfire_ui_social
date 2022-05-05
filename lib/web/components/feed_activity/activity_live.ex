defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Social.Activities
  import Where

  prop activity, :map
  prop object, :any
  prop verb_default, :string
  prop viewing_main_object, :boolean, default: false
  prop activity_inception, :string
  prop showing_within, :any, default: :feed
  prop hide_reply, :boolean, default: false
  prop class, :string, required: false, default: ""
  prop thread_object, :any
  prop participants, :list

  # TODO: put in config and/or autogenerate with Verbs genserver
  @reply_verbs ["reply", "respond"]
  @create_verbs ["create"]
  @react_verbs ["like", "boost", "flag", "tag"]
  @create_or_reply_verbs @create_verbs ++ @reply_verbs

  def render(%{activity: %{} = activity} = assigns) do
    # debug(assigns, "ActivityLive initial assigns")

    activity =
      activity
      |> repo().maybe_preload(:media)
      # |> debug("Activity provided")
      |> Map.put(:object, Activities.object_from_activity(assigns))
      |> debug("Activity with :object")

    verb =
      Activities.verb_maybe_modify(
        e(activity, :verb, nil) || e(assigns, :verb_default, "create"),
        activity
      )
      # |> debug("verb modified")

    verb_display = Activities.verb_display(verb)
    created_verb_display = Activities.verb_display("create")
    object_type = Bonfire.Common.Types.object_type(activity.object) |> debug("object_type")
    # |> String.downcase()
    object_type_readable = module_to_human_readable(object_type)

    thread = e(assigns, :thread_object, nil) || e(activity, :replied, :thread, nil) || e(activity, :replied, :thread_id, nil)

    thread_url = if thread do
      if is_struct(thread), do: path(thread), else: "/discussion/#{ulid(thread)}"
    end

    permalink =
      if thread_url && verb in ["reply", "respond"],
        do: "#{thread_url}##{activity.object.id}",
        else: "#{path(activity.object)}#"

    assigns = assigns
      |> assigns_merge(
        object: activity.object,
        object_id: e(activity.object, :id, nil) || e(activity, :id, "no-object-id"),
        object_type: object_type,
        object_type_readable: object_type_readable,
        date_ago: date_from_now(activity),
        activity: activity |> Map.drop([:object]),
        verb: verb,
        verb_display: verb_display,
        created_verb_display: created_verb_display,
        permalink: permalink
      )
      # |> dump("all assigns")
      |> Map.new()

    # permalink = path(activity.object)
    components = (
      component_activity_subject(verb, activity, assigns)
      ++
      component_maybe_in_reply_to(verb, activity, assigns)
      ++
      component_object(verb, activity, object_type)
      ++
      component_maybe_attachments(activity, assigns)
      ++
      component_actions(verb, activity, assigns)
      )
      |> Utils.filter_empty([])
      |> Enum.map(fn
        c when is_atom(c) -> {c, nil}
        other -> other
      end)
      # |> debug("components")

    ~F"""
    <article
      phx-click={if e(assigns, :showing_within, nil) !=:thread || e(assigns, :activity_inception, nil) ||  e(@object, :id, nil) == nil and e(@activity, :replied, :reply_to_id, nil) != nil and e(@activity, :id, nil) != nil, do: "Bonfire.Social.Feeds:open_activity"}
      phx-value-permalink={@permalink}
      id={"activity#{e(assigns, :activity_inception, nil)}-"<>( e(@activity, :id, nil) || e(@object, :id, "no-id") )}
      aria-label="user activity"
      role="article"
      tabIndex="0"
      class={
      "p-3 activity relative pl-16 group cursor-pointer " <> e(assigns, :class, ""),
      "hover:bg-base-content hover:bg-opacity-5": e(@object, :id, nil) == nil or e(@activity, :replied, :reply_to_id, nil) != nil or e(@activity, :id, nil) != nil, # Hover the activity background unless it is a quoted activity
      "bg-base-100 hover:bg-base-100 hover:bg-opacity-100 border-b border-base-300 p-0 pl-0": e(assigns, :viewing_main_object, nil) == true,
      "main_reply_to mb-2 p-2 py-1 mt-2 relative border-l-4 opacity-60 border-base-content border-opacity-40": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) == nil and e(@activity, :id, nil) == nil and e(assigns, :showing_within, nil) != :widget and e(assigns, :showing_within, nil) != :notification  and e(assigns, :showing_within, nil) != :search, # showing a quoted reply_to
      "reply": e(@object, :id, nil) != nil and e(@activity, :replied, :reply_to_id, nil) != nil and e(@activity, :id, nil) != nil,
    }>
      {#for {component, component_assigns} when is_atom(component) <- components}
        <Surface.Components.Dynamic.Component
          module={component}
          id={e(component_assigns, :id, nil)}
          myself={nil}
          created_verb_display={@created_verb_display}
          showing_within={e(assigns, :showing_within, :feed)}
          thread_mode={e(assigns, :thread_mode, nil)}
          participants={e(assigns, :participants, [])}
          activity={e(component_assigns, :activity, @activity)}
          object={e(component_assigns, :object, @object)}
          object_id={e(component_assigns, :object_id, @object_id)}
          object_type={e(component_assigns, :object_type, @object_type)}
          object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
          date_ago={e(component_assigns, :date_ago, @date_ago)}
          verb={e(component_assigns, :verb, @verb)}
          verb_display={e(component_assigns, :verb_display, @verb_display)}
          permalink={e(component_assigns, :permalink, @permalink)}
          activity_inception={e(component_assigns, :activity_inception, e(assigns, :activity_inception, nil))}
          viewing_main_object={e(component_assigns, :viewing_main_object, e(assigns, :viewing_main_object, false))}
          hide_reply={e(component_assigns, :hide_reply, e(assigns, :hide_reply, false))}
          profile={e(component_assigns, :profile, nil)}
          character={e(component_assigns, :character, nil)}
          media={e(component_assigns, :media, nil)}
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

  # don't show subject twice
  def component_activity_subject(_, %{object: %Bonfire.Data.Identity.User{}}, _), do: []

  # quoting a reply_to <-- this is handled by the Bonfire.UI.Social.Activity.SubjectLive internally
  # def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]

  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, _) when verb in @react_verbs,
    do: [
      {Bonfire.UI.Social.Activity.SubjectMinimalLive, %{
        activity: repo().maybe_preload(activity, subject: [:character]),
        verb: verb
      }},
      component_activity_maybe_creator(activity)
    ]

  # replies (when shown in notifications)
  def component_activity_subject(verb, activity, %{showing_within: :notifications})
      when verb in @reply_verbs,
      do: [
        {Bonfire.UI.Social.Activity.SubjectMinimalLive, %{
          activity: repo().maybe_preload(activity, subject: [:character]),
          verb: verb
        }}
      ]

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

  def component_activity_maybe_creator(%{provider: %{id: _}}),
    do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{primary_accountable: %{id: _} = primary_accountable}),
    do: {Bonfire.UI.Social.Activity.ProviderReceiverLive, %{provider: primary_accountable}}

  def component_activity_maybe_creator(%{receiver: %{id: _}}),
    do: Bonfire.UI.Social.Activity.ProviderReceiverLive

  def component_activity_maybe_creator(%{object: %{id: _} = object}),
    do: component_activity_maybe_creator(object)

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

  def component_activity_maybe_creator(%{subject: %{profile: _, character: _}} = object),
    do:
      object
      |> repo().maybe_preload(subject: [:profile, :character])
      |> e(:subject, nil)
      |> component_activity_maybe_creator()

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

  def component_maybe_in_reply_to(verb, activity, %{
    showing_within: showing_within,
    viewing_main_object: false,
    thread_mode: thread_mode})
  when showing_within in [:thread, :smart_input]
    and thread_mode not in [:flat], do: [] # do not show reply_to

  def component_maybe_in_reply_to(
        verb,
        %{
          id: activity_id,
          reply_to: %{
            post_content: %{id: id} = _reply_to_post_content,
            created: %{
              creator: %{
                character: %{id: _} = subject_character,
                profile: %{id: _} = subject_profile
              }
            }
          } = reply_to
        },
        _
      )
      # reply with post_content
      when verb in @reply_verbs,
      do: [
        {Bonfire.UI.Social.ActivityLive,
         %{
           id: "ra:" <> id,
           activity_inception: activity_id,
           viewing_main_object: false,
           object: reply_to,
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
          id: activity_id,
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
           activity_inception: activity_id,
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
          id: activity_id,
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
         activity_inception: activity_id,
         object: e(reply_to_activity, :object, nil),
         # |> IO.inspect,
         activity: reply_to_activity |> Map.delete(:object),
         viewing_main_object: false
       }}
    ]
  end

  def component_maybe_in_reply_to(verb, %{replied: %{} = replied}, assigns),
    do: component_maybe_in_reply_to(verb, replied, assigns)

  def component_maybe_in_reply_to(_, _a, _) do
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
    do: [{Bonfire.UI.Social.Activity.CharacterLive, %{
        object: repo().maybe_preload(object, [:character, profile: :icon])
      }}]

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

  def component_maybe_attachments(%{media: files}, assigns) when is_list(files) and length(files)>0 do
    [{Bonfire.UI.Social.Activity.MediaLive, %{media: files, showing_within: e(assigns, :showing_within, :feed)}}]
  end
  def component_maybe_attachments(_, _assigns) do
    []
  end

  def component_actions(_, _, %{activity_inception: activity_inception}) when not is_nil(activity_inception), do: [] # don't show any

  # WIP: THIS NEEDS TO BE REFACTORED ACCORDING TO actions_for_object_type
  def component_actions("flag", _, _), do: [Bonfire.UI.Social.Activity.FlaggedActionsLive]

  def component_actions(_, activity, %{viewing_main_object: true}) do
    [Bonfire.UI.Social.Activity.MainObjectInfoLive] ++ component_actions(nil, activity, nil)
  end

  def component_actions(_, %{object: %{}} = activity, _) do
    case Bonfire.Common.Types.object_type(activity.object) do
      type ->
        actions_for_object_type(activity, type)

      _ ->
        # warn("ActivityLive: object NOT recognised: #{object}")
        component_show_standard_actions(activity)
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

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicEvent],
  #   do: component_show_event_actions(activity)

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicResource],
  #   do: component_show_process_actions(activity)

  # # TODO: choose between Task and other Intent types
  # def actions_for_object_type(activity, type) when type in [ValueFlows.Planning.Intent],
  #   do: component_show_process_actions(activity)

  # # TODO: choose between Task and other Intent types
  # def actions_for_object_type(activity, type) when type in [ValueFlows.Process],
  #   do: component_show_process_actions(activity)

  def actions_for_object_type(activity, type) do
    debug(type, "No specific actions defiend fot this type")
    component_show_standard_actions(activity)
    # [Bonfire.UI.Social.Activity.NoActionsLive]
  end

  # |> debug
  def component_show_standard_actions(
        %{subject: %{character: %{username: username}}} = _activity
      ),
      do: [Bonfire.UI.Social.Activity.ActionsLive]

  def component_show_standard_actions(_activity), do: [Bonfire.UI.Social.Activity.ActionsLive]

  def component_show_process_actions(_activity),
    do: [Bonfire.UI.Social.Activity.ProcessActionsLive]

  def component_show_event_actions(activity) do
    [
      {Bonfire.UI.Social.Activity.EventActionsLive,
       %{object: e(activity, :object, :resource_inventoried_as, nil) || e(activity, :object, nil)}}
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

  def handle_event(action, attrs, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
end
