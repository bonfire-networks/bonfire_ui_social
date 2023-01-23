defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use Untangle

  alias Bonfire.Social.Activities
  alias Bonfire.Social.Feeds.LiveHandler

  prop(activity, :any, default: nil)
  prop(object, :any, default: nil)
  prop(verb, :string, default: nil)
  prop(verb_default, :string, default: nil)
  prop(verb_display, :string, default: nil)
  prop(object_type, :any, default: nil)
  prop(date_ago, :any, default: nil)
  prop(feed_id, :any, default: nil)
  prop(viewing_main_object, :boolean, default: false)
  prop(activity_inception, :string, default: nil)
  prop(showing_within, :any, default: :feed)
  prop(hide_reply, :boolean, default: false)
  prop(class, :string, required: false, default: "")
  prop(thread_object, :any, default: nil)
  prop(url, :string, default: nil)
  prop(permalink, :string, default: nil)
  prop(thread_url, :string, default: nil)
  prop(thread_mode, :any, default: nil)
  prop(participants, :list, default: [])
  prop(object_boundary, :any, default: nil)
  prop(check_object_boundary, :boolean, default: false)
  prop(hide_activities, :any, default: nil)
  prop(i, :integer, default: nil)

  # TODO: put verbs in config and/or autogenerate with Verbs genserver
  @reply_verbs Application.compile_env(:bonfire, [:verb_families, :reply])
  @create_verbs Application.compile_env(:bonfire, [:verb_families, :create])
  @react_verbs Application.compile_env(:bonfire, [:verb_families, :react])
  @simple_verbs Application.compile_env(:bonfire, [:verb_families, :simple_action])
  @react_or_simple_verbs @react_verbs ++ @simple_verbs
  @create_or_reply_verbs @create_verbs ++ @reply_verbs
  @created_verb_display Activities.verb_display("Create")

  @decorate time()
  def preload(list_of_assigns) do
    LiveHandler.preload(list_of_assigns,
      caller_module: __MODULE__
    )
  end

  defp debug_i(i, activity_inception), do: i || "inception-from-#{activity_inception}"

  def update(
        %{preloaded_async_activities: preloaded_async_activities, activity: activity} = _assigns,
        %{assigns: %{activity_components: _activity_components}} = socket
      )
      when preloaded_async_activities == true do
    debug(
      "Activity ##{debug_i(socket.assigns[:i], socket.assigns[:activity_inception])} prepared already, just assign updated activity"
    )

    {:ok,
     assign(
       socket,
       socket.assigns
       |> assigns_clean()
       |> Enum.into(%{
         activity: activity |> Map.drop([:object]),
         object: e(activity, :object, nil)
       })
       |> activity_components(activity, ...)
     )}
  end

  def update(
        %{object_boundary: object_boundary} = _assigns,
        %{assigns: %{activity_components: _activity_components}} = socket
      )
      when not is_nil(object_boundary) do
    debug(
      "Activity ##{debug_i(socket.assigns[:i], socket.assigns[:activity_inception])} prepared already, just assign object_boundary"
    )

    {:ok,
     socket
     |> assign(object_boundary: object_boundary)}
  end

  def update(assigns, %{assigns: %{activity_components: activity_components}} = socket) do
    debug(
      "Activity ##{debug_i(assigns[:i] || socket.assigns[:i], assigns[:activity_inception] || socket.assigns[:activity_inception])} prepared already"
    )

    # debug(activity_components)
    # |> assign(assigns)} # FYI: assigning blindly here causes problems
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(prepare(assigns))}
  end

  defp activity_with_object(activity, assigns) do
    activity
    # |> repo().maybe_preload(:media) # FIXME
    # |> debug("Activity provided")
    |> Map.put(
      :object,
      Activities.object_from_activity(assigns)
      # |> debug("object")
    )

    # |> debug("Activity with :object")
  end

  defp activity_components(activity, %{verb: verb, object_type: object_type} = assigns) do
    (component_activity_subject(verb, activity, assigns) ++
       component_maybe_in_reply_to(verb, activity, assigns) ++
       component_object(verb, activity, object_type) ++
       component_maybe_attachments(activity, assigns) ++
       component_actions(verb, activity, assigns))
    |> Utils.filter_empty([])
    |> Enum.map(fn
      c when is_atom(c) and not is_nil(c) -> {c, nil}
      other -> other
    end)
    |> debug("components")
    |> Map.put(assigns, :activity_components, ...)
  end

  @decorate time()
  def prepare(assigns)

  def prepare(%{activity: %{} = activity} = assigns) do
    debug("Activity ##{debug_i(assigns[:i], assigns[:activity_inception])} preparation started")
    # debug(assigns, "ActivityLive initial assigns")

    activity = activity_with_object(activity, assigns)

    verb =
      Activities.verb_maybe_modify(
        e(activity, :verb, nil) || e(assigns, :verb_default, "Create"),
        activity
      )
      |> debug("verb (modified)")

    verb_display = Activities.verb_display(verb)
    object_type = Types.object_type(activity.object) |> debug("object_type")
    object_type_readable = Types.object_type_display(object_type)

    thread =
      e(assigns, :thread_object, nil) || e(activity, :replied, :thread, nil) ||
        e(activity, :replied, :thread_id, nil)

    thread_id = ulid(thread)
    # debug(thread, "thread")
    thread_url =
      e(assigns, :thread_url, nil) ||
        if not is_nil(thread) do
          if is_struct(thread) do
            path(thread)
          else
            "/discussion/#{thread_id}"
          end
        end

    id = ulid(activity) || ulid(activity.object)
    # permalink = path(activity.object)
    permalink =
      if thread_url && thread_id != id,
        do: "#{thread_url}#activity-#{id}",
        else: "#{path(activity.object)}#"

    # debug(permalink, "permalink")

    assigns
    |> Map.merge(%{
      activity: activity |> Map.drop([:object]),
      object: e(activity, :object, nil),
      object_id: e(activity.object, :id, nil) || e(activity, :id, "no-object-id"),
      object_type: object_type,
      object_type_readable: object_type_readable,
      date_ago: date_from_now(id),
      verb: verb,
      verb_display: verb_display,
      created_verb_display: @created_verb_display,
      permalink: permalink,
      thread_url: thread_url,
      thread_id: thread_id,
      cw: e(activity.object, :post_content, :name, nil) != nil
    })
    |> activity_components(activity, ...)
  end

  def prepare(%{object: %{} = _object} = assigns) do
    prepare(
      Map.put(
        assigns,
        :activity,
        e(assigns.object, :activity, nil) ||
          %{
            subject:
              e(assigns.object, :created, :creator, nil) || e(assigns.object, :creator, nil)
          }
      )
    )
  end

  def prepare(assigns), do: Map.put(assigns, :activity_components, [])

  def render(%{activity: _, activity_components: _} = assigns) do
    do_render(assigns)
  end

  def render(%{activity: _} = assigns) do
    debug(
      assigns,
      "Activity ##{debug_i(assigns[:i], assigns[:activity_inception])} attempt preparation in render/1"
    )

    # needed to activity inception (eg. show reply_to)

    prepare(assigns)
    |> debug(
      "Activity ##{debug_i(assigns[:i], assigns[:activity_inception])} done with preparation in render"
    )
    |> do_render()
  end

  def render(assigns) do
    warn("No activity provided")
    debug(assigns)

    ~F"""
    """
  end

  @decorate time()
  defp do_render(%{activity: _, activity_components: _} = assigns) do
    ~F"""
    <article
      x-data="{content_open: false}"
      x-init={"content_open = #{!@cw}"}
      id={"activity-#{@activity_inception}-" <> (ulid(@activity) || e(@object, :id, "no-id"))}
      aria-label="user activity"
      phx-hook={if !@viewing_main_object and current_user(@__context__) != nil and
           e(assigns, :showing_within, :feed) != :thread,
         do: "PreviewActivity"}
      role="article"
      tabIndex="0"
      class={
        "p-4 activity relative group flex flex-col " <> e(assigns, :class, ""),
        # "!pl-12":
        #   e(assigns, :showing_within, :feed) == :thread and
        #     e(assigns, :viewing_main_object, false) == false,
        "": e(assigns, :showing_within, :feed) in [:feed, :notifications, :likes, :search],
        # "activity_inception bg-base-content/10 !m-0 opacity-100 before:!left-2 before:top-1 before:bottom-1":
        #   e(assigns, :activity_inception, nil) != nil and e(assigns, :thread_mode, nil) == :flat,
        # showing a quoted reply_to
        "main_reply_to !mb-1 items-center !flex-row order-first !p-0 !pb-2":
          ulid(@object) != nil and e(@activity, :replied, :reply_to_id, nil) == nil and
            ulid(@activity) == nil and @showing_within != :widget and
            @showing_within != :search,
        "": @showing_within != :thread and e(assigns, :thread_mode, nil) != :flat,
        reply:
          ulid(@object) != nil and e(@activity, :replied, :reply_to_id, nil) != nil and
            ulid(@activity) != nil,
        "unread-activity":
          e(@activity, :seen, nil) == nil and @showing_within == :notifications and
            @activity_inception == nil,
        "active-activity": String.contains?(@url || "", @permalink)
      }
    >
      <form
        :if={!ulid(e(@activity, :seen, nil)) and not is_nil(@feed_id) and
          @showing_within in [:messages, :thread, :notifications] and
          e(@activity, :subject, :id, nil) != ulid(current_user(assigns)) and
          e(@activity, :object, :created, :creator_id, nil) != ulid(current_user(assigns))}
        phx-submit="Bonfire.Social.Feeds:mark_seen"
        phx-target={"#badge_counter_#{@feed_id || "missing_feed_id"}"}
        x-intersect.once="$el.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true})); $el.parentNode.classList.remove('unread-activity');"
      >
        <input type="hidden" name="feed_id" value={@feed_id}>
        <input type="hidden" name="activity_id" value={ulid(@activity)}>
      </form>

      {#if @hide_activities != "all"}
        {#for {component, component_assigns} when is_atom(component) <- @activity_components || []}
          {#case component}
            {#match _
              when component in [
                     Bonfire.UI.Social.Activity.SubjectLive,
                     Bonfire.UI.Social.Activity.SubjectMinimalLive
                   ]}
              <Dynamic.Component
                :if={@hide_activities != "subject"}
                module={component}
                profile={e(component_assigns, :profile, nil)}
                character={e(component_assigns, :character, nil)}
                verb={e(component_assigns, :verb, @verb)}
                verb_display={e(component_assigns, :verb_display, @verb_display)}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                object_boundary={@object_boundary}
                object_type={e(component_assigns, :object_type, @object_type)}
                date_ago={e(component_assigns, :date_ago, @date_ago)}
                permalink={e(component_assigns, :permalink, @permalink)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                showing_within={@showing_within}
                thread_id={@thread_id}
                cw={@cw}
              />
            {#match Bonfire.UI.Social.Activity.MediaLive}
              <Bonfire.UI.Social.Activity.MediaLive
                :if={@hide_activities != "media"}
                __context__={@__context__}
                showing_within={@showing_within}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                media={e(component_assigns, :media, nil)}
              />
            {#match _ when component in [Bonfire.UI.Social.Activity.ActionsLive, Bonfire.UI.Social.FlaggedActionsLive]}
              <Dynamic.Component
                :if={@hide_activities != "actions"}
                module={component}
                __context__={@__context__}
                showing_within={@showing_within}
                thread_mode={@thread_mode}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                object_boundary={@object_boundary}
                object_type={e(component_assigns, :object_type, @object_type)}
                object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
                date_ago={e(component_assigns, :date_ago, @date_ago)}
                verb={e(component_assigns, :verb, @verb)}
                permalink={e(component_assigns, :permalink, @permalink)}
                activity_inception={e(component_assigns, :activity_inception, @activity_inception)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
              />
            {#match Bonfire.UI.Social.Activity.NoteLive}
              <Bonfire.UI.Social.Activity.NoteLive
                :if={@hide_activities != "note" and !show_minimal_reply?(@object, @activity, @showing_within)}
                showing_within={@showing_within}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                activity_inception={e(component_assigns, :activity_inception, @activity_inception)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                cw={@cw}
              />
            {#match _}
              <Dynamic.Component
                :if={@hide_activities != "dynamic"}
                module={component}
                id={e(component_assigns, :id, nil)}
                myself={nil}
                created_verb_display={@created_verb_display}
                showing_within={@showing_within}
                thread_mode={@thread_mode}
                participants={@participants || []}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                object_id={e(component_assigns, :object_id, @object_id)}
                object_boundary={@object_boundary}
                object_type={e(component_assigns, :object_type, @object_type)}
                object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
                date_ago={e(component_assigns, :date_ago, @date_ago)}
                verb={e(component_assigns, :verb, @verb)}
                verb_display={e(component_assigns, :verb_display, @verb_display)}
                permalink={e(component_assigns, :permalink, @permalink)}
                thread_url={@thread_url}
                thread_id={@thread_id}
                activity_inception={e(component_assigns, :activity_inception, @activity_inception)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                hide_reply={e(component_assigns, :hide_reply, @hide_reply)}
                profile={e(component_assigns, :profile, nil)}
                character={e(component_assigns, :character, nil)}
                media={e(component_assigns, :media, nil)}
              />
          {/case}
        {/for}
      {/if}
    </article>
    """
  end

  def show_minimal_reply?(object, activity, showing_within) do
    (e(object, :post_content, nil) != nil and showing_within == :smart_input) or
      (id(object) != nil and e(activity, :replied, :reply_to_id, nil) == nil and
         id(activity) == nil and showing_within != :search)
  end

  @decorate time()
  def component_activity_subject(verb, activity, assigns)

  # don't show subject twice
  def component_activity_subject(_, _, %{object_type: Bonfire.Data.Identity.User}),
    do: [Bonfire.UI.Social.Activity.SubjectMinimalLive]

  # quoting a reply_to <-- this is handled by the Bonfire.UI.Social.Activity.SubjectLive internally
  # def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]

  def component_activity_subject(verb, activity, %{object_type: object_type})
      when verb in @react_or_simple_verbs and object_type in [Bonfire.Data.Identity.User],
      do: [
        {Bonfire.UI.Social.Activity.SubjectMinimalLive,
         %{
           verb: verb
         }}
      ]

  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, assigns) when verb in @react_or_simple_verbs,
    do:
      [
        {Bonfire.UI.Social.Activity.SubjectMinimalLive,
         %{
           # activity: repo().maybe_preload(activity, subject: [:character]),
           verb: verb
         }}
      ] ++ component_activity_maybe_creator(activity, assigns)

  # replies (when shown in notifications)
  def component_activity_subject(verb, activity, %{showing_within: :notifications})
      when verb in @reply_verbs,
      do: [
        {Bonfire.UI.Social.Activity.SubjectMinimalLive,
         %{
           #  activity: repo().maybe_preload(activity, subject: [:character]),
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
  def component_activity_subject(verb, activity, assigns),
    do:
      activity
      # |> debug("activity")
      |> component_activity_maybe_creator(assigns)

  @decorate time()
  def component_activity_maybe_creator(activity, assigns)

  def component_activity_maybe_creator(_, %{object_type: object_type})
      when object_type in [Bonfire.Data.Identity.User],
      do: []

  def component_activity_maybe_creator(%{object: %{id: _} = object} = activity, _),
    # |> debug("based on object")
    # |> debug("activity")
    do:
      component_maybe_creator(object) ||
        component_maybe_creator(activity)

  def component_activity_maybe_creator(activity, _) do
    component_maybe_creator(activity)
  end

  def component_maybe_creator(%{
        creator_profile: %{id: _} = profile,
        creator_character: %{id: _} = character
      }),
      do: component_maybe_creator(%{profile: profile, character: character})

  # def component_maybe_creator(%{provider: %{id: _} = provider} = object),
  #   do: [{Bonfire.UI.Social.Activity.ProviderReceiverLive, %{object: object}}]

  # def component_maybe_creator(%{primary_accountable: %{id: _} = primary_accountable} = object),
  #   do: [{Bonfire.UI.Social.Activity.ProviderReceiverLive, %{object: object}}]

  # def component_maybe_creator(%{receiver: %{id: _} = receiver} = object),
  #   do: [{Bonfire.UI.Social.Activity.ProviderReceiverLive, %{object: object}}]

  def component_maybe_creator(%{created: %{creator: %{id: _}}} = object),
    do:
      object
      # |> repo().maybe_preload(created: [creator: [:profile, :character]])
      |> e(:created, :creator, nil)
      |> component_maybe_creator()

  def component_maybe_creator(%{created: %{creator: %{profile: _}}} = object),
    do:
      object
      |> e(:created, :creator, nil)
      |> component_maybe_creator()

  def component_maybe_creator(%{created: %{creator: %{character: _}}} = object),
    do:
      object
      |> e(:created, :creator, nil)
      |> component_maybe_creator()

  def component_maybe_creator(%{creator: %{id: _}} = object),
    do:
      object
      # |> repo().maybe_preload(creator: [:profile, :character])
      |> e(:creator, nil)
      |> component_maybe_creator()

  # def component_maybe_creator(%{subject: %{profile: _, character: _}} = object),
  #   do:
  #     object
  #     # |> repo().maybe_preload(subject: [:profile, :character])
  #     |> e(:subject, nil)
  #     |> component_maybe_creator()

  def component_maybe_creator(
        %{
          profile: %{id: _} = profile,
          character: %{id: _} = character
        } = _creator
      ),
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]

  # def component_maybe_creator(
  #       %{provider: %Ecto.Association.NotLoaded{}, receiver: %Ecto.Association.NotLoaded{}} =
  #         object
  #     ),
  #     do:
  #       object
  #       |> repo().maybe_preload(
  #         provider: [:profile, :character],
  #         receiver: [:profile, :character]
  #       )
  #       |> component_maybe_creator()

  # def component_maybe_creator(%{provider: %Ecto.Association.NotLoaded{}} = object),
  #   do:
  #     object
  #     |> repo().maybe_preload(
  #       provider: [:profile, :character],
  #       receiver: [:profile, :character],
  #       primary_accountable: [:profile, :character]
  #     )
  #     |> component_maybe_creator()

  # def component_maybe_creator(%{receiver: %Ecto.Association.NotLoaded{}} = object),
  #   do:
  #     object
  #     |> repo().maybe_preload(
  #       provider: [:profile, :character],
  #       receiver: [:profile, :character],
  #       primary_accountable: [:profile, :character]
  #     )
  #     |> component_maybe_creator()

  # def component_maybe_creator(%{primary_accountable: %Ecto.Association.NotLoaded{}} = object),
  #   do:
  #     object
  #     |> repo().maybe_preload(
  #       provider: [:profile, :character],
  #       receiver: [:profile, :character],
  #       primary_accountable: [:profile, :character]
  #     )
  #     |> component_maybe_creator()

  def component_maybe_creator(activity) do
    error(activity, "ActivityLive: could not find the creator")
    []
  end

  @decorate time()
  def component_maybe_in_reply_to(verb, activity, assigns)

  def component_maybe_in_reply_to(verb, activity, %{
        activity_inception: activity_inception,
        showing_within: showing_within,
        viewing_main_object: viewing_main_object,
        thread_mode: thread_mode
      })
      # do not show reply_to
      when not is_nil(activity_inception) or
             (viewing_main_object != true and showing_within in [:thread, :smart_input] and
                thread_mode not in [:flat]),
      do: []

  def component_maybe_in_reply_to(
        verb,
        %{
          id: activity_id,
          reply_to:
            %{
              post_content: %{id: id} = _reply_to_post_content,
              created: %{
                creator: %{
                  character: %{id: _} = subject_character,
                  profile: %{id: _} = subject_profile
                }
              }
            } = reply_to
        },
        assigns
      )
      when verb in @reply_verbs do
    debug("we have a reply_to, preloaded with post_content")

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "ra:" <> id,
         activity_inception: assigns[:i] || activity_id,
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
  end

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
        assigns
      )
      when verb in @reply_verbs and is_binary(reply_to_id) do
    debug("we have another kind of reply_to, preloaded with creator")

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "ra:" <> reply_to_id,
         activity_inception: assigns[:i] || activity_id,
         viewing_main_object: false,
         object: Activities.load_object(replied, skip_boundary_check: true),
         activity: %{
           subject: %{
             profile: subject_profile,
             character: subject_character
           }
         }
       }}
    ]
  end

  # def component_maybe_in_reply_to(
  #       verb,
  #       %{
  #         id: activity_id,
  #         reply_to:
  #           %{
  #             id: reply_to_id
  #           } = replied
  #       },
  #       assigns
  #     )
  #     # other kind of reply
  #     when verb in @reply_verbs and is_binary(reply_to_id) do
  #   maybe_load_in_reply_to(replied, assigns[:i] || activity_id, current_user: current_user(assigns))
  # end

  def component_maybe_in_reply_to(verb, %{replied: %{} = replied}, assigns),
    do: component_maybe_in_reply_to(verb, replied, assigns)

  # def component_maybe_in_reply_to(
  #       verb,
  #       %{id: object_id, thread: %{id: thread_id} = thread},
  #       assigns
  #     )
  #     when object_id != thread_id,
  #     do: maybe_load_in_reply_to(thread, assigns[:i] || thread_id, current_user: current_user(assigns))

  def component_maybe_in_reply_to(_, a, _) do
    # debug(a, "ActivityLive: no reply_to")
    []
  end

  # @decorate time()
  # def maybe_load_in_reply_to(
  #       %{
  #         id: reply_to_id
  #       } = replied,
  #       activity_inception,
  #       opts
  #     ) do
  #   warn("FIXME: avoid n+1 and preload at feed level")
  #   reply_to_activity = load_reply_to(replied, opts)

  #   [
  #     {Bonfire.UI.Social.ActivityLive,
  #      %{
  #        id: "ra:" <> reply_to_id,
  #        activity_inception: activity_inception,
  #        object: e(reply_to_activity, :object, nil),
  #        # |> IO.inspect,
  #        activity: reply_to_activity |> Map.delete(:object),
  #        viewing_main_object: false
  #      }}
  #   ]
  # end

  # def load_reply_to(reply_to, opts) do
  #   reply_to =
  #     Activities.load_object(reply_to, opts)
  #     # |> debug()

  #   %{
  #     object: reply_to,
  #     subject: %{
  #       profile: e(reply_to, :created, :creator_profile, nil),
  #       character: e(reply_to, :created, :creator_character, nil)
  #     }
  #   }
  # end

  @decorate time()
  def component_object(verb, activity, assigns)

  def component_object(_, %{object: %{post_content: %{html_body: _}}}, _),
    do: [Bonfire.UI.Social.Activity.NoteLive]

  # def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_object(_, %{object: %{} = object}, object_type) do
    case object_type do
      type when is_atom(type) and not is_nil(type) ->
        debug("ActivityLive: component object_type recognised: #{inspect(type)}")
        component_for_object_type(type, object)

      _ ->
        warn(
          "ActivityLive: use UnknownLive because component object_type NOT detected: #{inspect(object)}"
        )

        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, _activity, _) do
    debug("ActivityLive: activity has no object")
    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_for_object_type(type, %{post_content: %{html_body: _}})
      when type in [Bonfire.Data.Social.Post],
      do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, object) when type in [Bonfire.Data.Social.Post],
    # for posts with no text content (eg. only with attachments)
    do: []

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.Message],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.PostContent],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Identity.User],
    do: [Bonfire.UI.Social.Activity.CharacterLive]

  # do: [{Bonfire.UI.Social.Activity.CharacterLive, %{
  #     object: repo().maybe_preload(object, [:character, profile: :icon])
  #   }}]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.Follow],
    do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_for_object_type(type, _) when type in [Bonfire.Classify.Category],
    do: [Bonfire.UI.Social.Activity.CategoryLive]

  def component_for_object_type(type, object) when type in [ValueFlows.EconomicEvent],
    do: [Bonfire.UI.Social.Activity.EconomicEventLive.activity_component(object)]

  def component_for_object_type(type, _) when type in [ValueFlows.EconomicResource],
    do: [Bonfire.UI.Social.Activity.EconomicResourceLive]

  # TODO: choose between Task and other Intent types
  def component_for_object_type(type, _) when type in [ValueFlows.Planning.Intent],
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

  def component_maybe_attachments(%{media: files}, assigns)
      when is_list(files) and length(files) > 0 do
    [
      {Bonfire.UI.Social.Activity.MediaLive,
       %{media: files, showing_within: e(assigns, :showing_within, :feed)}}
    ]
  end

  def component_maybe_attachments(_, _assigns) do
    []
  end

  @decorate time()
  def component_actions(verb, activity, assigns)

  # don't show any
  def component_actions(_, _, %{activity_inception: activity_inception})
      when not is_nil(activity_inception),
      do: []

  def component_actions(_, _, %{showing_within: showing_within})
      when showing_within == :smart_input,
      do: []

  # WIP: THIS NEEDS TO BE REFACTORED ACCORDING TO actions_for_object_type
  def component_actions("Flag", _, _), do: [Bonfire.UI.Social.FlaggedActionsLive]

  # def component_actions(_, activity, %{viewing_main_object: true}) do
  #   [Bonfire.UI.Social.Activity.MainObjectInfoLive] ++ component_actions(nil, activity, nil)
  # end

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
      do: []

  def actions_for_object_type(activity, type) when type in [Bonfire.Data.Social.Flag], do: []

  def actions_for_object_type(activity, type)
      when type in [Bonfire.Data.Social.Post, Bonfire.Data.Social.PostContent],
      do: component_show_standard_actions(activity)

  # def actions_for_object_type(activity, type)
  #     when type in [Bonfire.Classify.Category],
  #     do: component_show_category_actions(activity)
  def actions_for_object_type(activity, type)
      when type in [Bonfire.Classify.Category],
      do: []

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicEvent],
  #   do: component_show_event_actions(activity)

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicResource],
  #   do: component_show_process_actions(activity)

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(activity, type) when type in [ValueFlows.Planning.Intent],
    do: []

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(activity, type) when type in [ValueFlows.Process],
    do: []

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

  def component_show_category_actions(_activity),
    do: [Bonfire.UI.Social.Activity.CategoryActionsLive]

  def component_show_process_actions(_activity),
    do: [Bonfire.UI.Social.Activity.ProcessActionsLive]

  def component_show_event_actions(activity) do
    [
      {Bonfire.UI.Social.Activity.EventActionsLive,
       %{object: e(activity, :object, :resource_inventoried_as, nil) || e(activity, :object, nil)}}
    ]
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

  defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
