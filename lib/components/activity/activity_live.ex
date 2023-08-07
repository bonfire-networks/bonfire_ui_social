defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use Untangle

  alias Bonfire.Social.Activities
  # alias Bonfire.Data.Social.Activity
  alias Bonfire.Social.Feeds.LiveHandler

  # TODO: autogenerate with Verbs genserver?
  @reply_verbs Application.compile_env(:bonfire, [:verb_families, :reply])
  @create_verbs Application.compile_env(:bonfire, [:verb_families, :create])
  @react_verbs Application.compile_env(:bonfire, [:verb_families, :react])
  @simple_verbs Application.compile_env(:bonfire, [:verb_families, :simple_action])
  @react_or_simple_verbs @react_verbs ++ @simple_verbs
  @create_or_reply_verbs @create_verbs ++ @reply_verbs
  @created_verb_display Activities.verb_display("Create")

  prop(activity, :any, default: nil)
  prop(activity_id, :string, default: nil)
  prop(object, :any, default: nil)
  prop(object_id, :string, default: nil)
  prop(object_type, :any, default: nil)
  prop(verb, :string, default: nil)
  prop(verb_default, :string, default: nil)
  prop(verb_display, :string, default: nil)
  prop(date_ago, :any, default: nil)
  prop(feed_id, :any, default: nil)
  prop(activity_component_id, :any, default: nil)
  prop(viewing_main_object, :boolean, default: false)
  prop(activity_inception, :string, default: nil)
  prop(showing_within, :any, default: nil)
  prop(hide_reply, :boolean, default: false)
  prop(class, :string, required: false, default: "")
  prop(thread_id, :string, default: nil)
  prop(thread_object, :any, default: nil)
  prop(thread_url, :string, default: nil)
  prop(thread_title, :string, default: nil)
  prop(thread_mode, :any, default: nil)
  prop(current_url, :string, default: nil)
  prop(permalink, :string, default: nil)
  prop(participants, :list, default: [])
  prop(object_boundary, :any, default: nil)
  prop(cw, :any, default: nil)
  prop(check_object_boundary, :boolean, default: false)
  prop(is_remote, :boolean, default: false)
  prop(show_minimal_subject_and_note, :any, default: false)
  prop(hide_activity, :any, default: nil)
  prop(i, :integer, default: nil)
  prop(created_verb_display, :string, default: @created_verb_display)
  prop(object_type_readable, :string, default: nil)
  prop(reply_count, :any, default: nil)
  prop(published_in, :any, default: nil)

  prop(hide_actions_until_hovered, :boolean, default: false)

  @decorate time()
  def preload(list_of_assigns) do
    LiveHandler.preload(list_of_assigns,
      caller_module: __MODULE__
    )
  end

  defp debug_i(i, activity_inception), do: i || "inception-from-#{activity_inception}"

  @spec update(map, any) :: {:ok, any}
  def update(%{activity_remove: true}, socket) do
    {:ok, remove(socket)}
  end

  def update(
        %{preloaded_async_activities: preloaded_async_activities, activity: activity} = assigns,
        %{assigns: %{activity_prepared: _}} = socket
      )
      when preloaded_async_activities == true do
    debug(
      "Activity ##{debug_i(socket.assigns[:activity_id], socket.assigns[:activity_inception])} prepared already, just assign updated activity"
    )

    {:ok,
     assign(
       socket,
       activity: if(is_map(activity), do: Map.drop(activity, [:object])),
       object: e(activity, :object, nil),
       published_in: maybe_published_in(activity, nil),
       thread_title:
         e(assigns, :thread_title, nil) || e(socket.assigns, :thread_title, nil) ||
           e(activity, :replied, :thread, :named, :name, nil),
       thread_mode: e(assigns, :thread_mode, nil) || e(socket.assigns, :thread_mode, nil)
     )}
  end

  def update(
        %{update_activity: true} = assigns,
        socket
      ) do
    debug("Activity - assigns with `update_activity` so we update them")

    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(
        %{object_boundary: object_boundary} = _assigns,
        %{assigns: %{activity_prepared: _}} = socket
      )
      when not is_nil(object_boundary) do
    debug(
      "Activity ##{debug_i(socket.assigns[:activity_id], socket.assigns[:activity_inception])} prepared already, just assign object_boundary"
    )

    {:ok,
     socket
     |> assign(object_boundary: object_boundary)}
  end

  def update(assigns, %{assigns: %{activity_prepared: _}} = socket) do
    debug(
      "Activity ##{debug_i(assigns[:activity_id] || socket.assigns[:activity_id], assigns[:activity_inception] || socket.assigns[:activity_inception])} prepared already"
    )

    # FYI: assigning blindly here causes problems
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(prepare(assigns))}
  end

  def remove(socket) do
    assign(
      socket,
      hide_activity: "all",
      activity: %{},
      object: %{}
    )
  end

  @decorate time()
  def prepare(assigns)

  def prepare(%{activity: _, object: %{}} = assigns) do
    do_prepare(assigns)
  end

  def prepare(%{activity: %{object: object}, object: nil} = assigns) when not is_nil(object) do
    debug(
      "Activity ##{debug_i(assigns[:activity_id], assigns[:activity_inception])} prepare activity with object in assoc"
    )

    Map.put(assigns, :object, object)
    |> do_prepare()
  end

  def prepare(assigns), do: Map.put(assigns, :activity_prepared, :skipped)

  defp do_prepare(%{activity: activity, object: object} = assigns) when not is_nil(object) do
    # debug("Activity ##{debug_i(assigns[:activity_id], assigns[:activity_inception])} preparation started")
    # debug(assigns, "initial assigns")

    # debug(object, "object")

    verb =
      Activities.verb_maybe_modify(
        e(activity, :verb, nil) || e(activity, :verb_id, nil) ||
          e(assigns, :verb_default, "Create"),
        activity
      )

    # |> debug("verb (modified)")

    verb_display = Activities.verb_display(verb)
    object_type = Types.object_type(object)
    # |> debug("object_type")
    object_type_readable = Types.object_type_display(object_type)

    replied = e(activity, :replied, nil) || e(object, :replied, nil)

    thread =
      e(assigns, :thread_object, nil) || e(replied, :thread, nil) || e(replied, :thread_id, nil)

    thread_id = id(thread)
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

    debug(activity, "theactivity")

    object_id = id(object)
    id = object_id || id(activity)

    current_url =
      (assigns[:current_url] || current_url(assigns[:__context__]))
      |> debug("activity_current_url")

    # permalink = path(object)
    permalink =
      if(thread_url && thread_id != id,
        do: "#{thread_url}#comment_#{id}",
        else: "#{path(object)}#"
      )
      |> String.trim_leading("#{current_url || "#"}#")

    # |> debug()

    assigns
    |> Map.merge(%{
      activity_prepared: true,
      activity_id: id || "no-activity-id",
      object_id: object_id || "no-object-id",
      activity_component_id:
        Enums.id(assigns) ||
          "activity-#{e(assigns, :activity_inception, nil)}-#{id || "no-activity-id"}",
      object_type: object_type,
      object_type_readable: object_type_readable,
      # unit: :minute
      date_ago: DatesTimes.date_from_now(object_id || id, format: :narrow),
      # if(e(assigns[:__context], :ui_compact, nil),
      #   do: DatesTimes.date_from_now(id, format: :narrow),
      #   else: DatesTimes.date_from_now(id)
      # ),
      verb: verb,
      verb_display: verb_display,
      created_verb_display: e(assigns, :created_verb_display, nil),
      permalink: permalink,
      thread_url: thread_url,
      current_url: current_url,
      thread_id: thread_id,
      thread_title: e(assigns, :thread_title, nil) || e(thread, :named, :name, nil),
      published_in: maybe_published_in(activity, verb),
      cw: e(object, :post_content, :name, nil) != nil,
      is_remote: e(activity, :peered, nil) != nil or e(object, :peered, nil) != nil,
      reply_count: e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0),
      hide_actions_until_hovered:
        !e(assigns, :viewing_main_object, nil) and
          Settings.get(
            [
              Bonfire.UI.Social.Activity.ActionsLive,
              e(assigns, :showing_within, nil) || :feed,
              :hide_until_hovered
            ],
            nil,
            assigns
          )
    })

    # |> debug("Activity preparation done")
  end

  defp do_prepare(assigns), do: Map.put(assigns, :activity_prepared, :skipped)

  def maybe_published_in(%{subject: %{table_id: "2AGSCANBECATEG0RY0RHASHTAG"} = subject}, "Boost") do
    subject
  end

  def maybe_published_in(%{tree: %{parent: %{id: _} = parent}}, _) do
    parent
  end

  def maybe_published_in(%{tree: %{parent_id: parent_id}}, _) do
    parent_id
  end

  def maybe_published_in(none, _) do
    # debug(none, "none")
    nil
  end

  defp activity_components(
         activity,
         verb,
         object,
         object_type,
         activity_inception,
         showing_within,
         viewing_main_object,
         thread_mode,
         thread_id,
         thread_title,
         activity_component_id
       ) do
    (component_maybe_in_reply_to(
       verb,
       activity,
       showing_within,
       activity_inception,
       viewing_main_object,
       thread_mode,
       thread_id,
       thread_title,
       activity_component_id
     ) ++
       component_activity_subject(
         verb,
         activity,
         object,
         object_type,
         showing_within,
         activity_inception
       ) ++
       component_object(verb, activity, object, object_type) ++
       component_maybe_attachments(
         e(activity, :files, nil) || e(object, :files, nil) || e(activity, :media, nil) ||
           e(object, :media, nil)
       ) ++
       component_actions(
         verb,
         activity,
         object_type,
         showing_within,
         activity_inception,
         viewing_main_object
       ))
    |> Enums.filter_empty([])
    |> Enum.map(fn
      c when is_atom(c) and not is_nil(c) -> {c, nil}
      other -> other
    end)
    |> debug("components")
  end

  def maybe_prepare(%{activity: _, activity_prepared: _} = assigns) do
    assigns
  end

  def maybe_prepare(%{activity: _} = assigns) do
    prepare(assigns)
  end

  def render(%{activity: _} = assigns) do
    assigns = maybe_prepare(assigns)

    ~F"""
    <article
      x-data="{content_open: false, show_actions: false}"
      x-init={"content_open = #{!@cw}; show_actions = #{if @hide_actions_until_hovered, do: "('ontouchstart' in window) || (navigator.maxTouchPoints > 0) || (navigator.msMaxTouchPoints > 0)", else: true}"}
      x-on:mouseover={if @hide_actions_until_hovered, do: "show_actions=true"}
      x-on:mouseover.away={if @hide_actions_until_hovered, do: "show_actions=false"}
      id={@activity_component_id}
      data-href={@permalink}
      phx-hook={if !@viewing_main_object and !@show_minimal_subject_and_note and
           @showing_within != :thread,
         do: "PreviewActivity"}
      role="article"
      aria-label="user activity"
      tabIndex="0"
      class={
        "p-4 pb-2 activity relative flex flex-col #{@class}",
        "!p-0 !pb-4 hover:!bg-transparent": e(@show_minimal_subject_and_note, false),
        "main_reply_to !mb-1 items-center !flex-row order-first !p-0 !pb-2":
          @object_id != nil and e(@activity, :replied, :reply_to_id, nil) == nil and
            @activity_id == nil and @showing_within != :widget and
            @showing_within != :search,
        "": @showing_within != :thread and @thread_mode != :flat,
        "hover:bg-base-content/5 cursor-pointer": @showing_within == :notifications,
        reply:
          @object_id != nil and e(@activity, :replied, :reply_to_id, nil) != nil and
            @activity_id != nil,
        "unread-activity":
          e(@activity, :seen, nil) == nil and @showing_within == :notifications and
            @activity_inception == nil,
        "active-activity":
          String.contains?(@current_url || "", @permalink || "") and @showing_within != :smart_input
      }
    >
      <form
        :if={!id(e(@activity, :seen, nil)) and not is_nil(@feed_id) and
          @showing_within in [:messages, :thread, :notifications] and
          e(@activity, :subject, :id, nil) != current_user_id(@__context__) and
          e(@object, :created, :creator_id, nil) != current_user_id(@__context__) and
          e(@object, :created, :creator_id, nil) != current_user_id(@__context__)}
        phx-submit="Bonfire.Social.Feeds:mark_seen"
        phx-target={"#badge_counter_#{@feed_id || "missing_feed_id"}"}
        x-intersect.once="$el.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true})); $el.parentNode.classList.remove('unread-activity');"
      >
        <input type="hidden" name="feed_id" value={@feed_id}>
        <input type="hidden" name="activity_id" value={@activity_id}>
      </form>
      <div
        :if={@viewing_main_object && (@thread_title || e(@activity, :replied, :thread, :named, :name, nil))}
        class="flex items-center mb-4 font-bold gap-2 text-2xl tracking-wider"
      >
        <span class="">{@thread_title || e(@activity, :replied, :thread, :named, :name, "")}</span>
      </div>

      {#if @hide_activity != "all"}
        {#for {component, component_assigns} when is_atom(component) <-
            activity_components(
              @activity,
              @verb,
              @object,
              @object_type,
              @activity_inception,
              @showing_within,
              @viewing_main_object,
              @thread_mode,
              @thread_id,
              @thread_title,
              @activity_component_id
            ) || []}
          {#case component}
            {#match _
              when component in [
                     Bonfire.UI.Social.Activity.SubjectLive,
                     Bonfire.UI.Social.Activity.SubjectMinimalLive
                   ]}
              <Dynamic.Component
                :if={@hide_activity != "subject"}
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
                show_minimal_subject_and_note={@show_minimal_subject_and_note}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                activity_component_id={e(component_assigns, :activity_component_id, @activity_component_id)}
                showing_within={@showing_within}
                thread_id={@thread_id}
                cw={@cw}
                published_in={@published_in}
                thread_title={e(component_assigns, :thread_title, @thread_title)}
              />
            {#match Bonfire.UI.Social.Activity.NoteLive}
              <Bonfire.UI.Social.Activity.NoteLive
                :if={@hide_activity != "note" and !@show_minimal_subject_and_note}
                showing_within={@showing_within}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                activity_inception={e(component_assigns, :activity_inception, @activity_inception)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                cw={@cw}
                thread_mode={@thread_mode}
                is_remote={@is_remote}
              />
            {#match _
              when component in [
                     Bonfire.UI.Social.Activity.UnknownLive,
                     Bonfire.UI.Social.Activity.UnknownActivityStreamsLive
                   ]}
              <Dynamic.Component
                module={component}
                __context__={@__context__}
                showing_within={@showing_within}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                object={e(component_assigns, :object, @object)}
                object_type={e(component_assigns, :object_type, @object_type)}
                object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
                json={e(component_assigns, :json, nil)}
              />
            {#match Bonfire.UI.Social.Activity.MediaLive}
              <Bonfire.UI.Social.Activity.MediaLive
                :if={@hide_activity != "media" and @showing_within != :smart_input}
                __context__={@__context__}
                showing_within={@showing_within}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                media={List.wrap(e(component_assigns, :media, []))}
              />
            {#match _ when component in [Bonfire.UI.Social.Activity.ActionsLive, Bonfire.UI.Social.FlaggedActionsLive]}
              <Dynamic.Component
                :if={@hide_activity != "actions"}
                module={component}
                __context__={@__context__}
                showing_within={@showing_within}
                thread_mode={@thread_mode}
                profile={e(component_assigns, :profile, nil)}
                activity={e(component_assigns, :activity, @activity)}
                object={e(component_assigns, :object, @object)}
                object_boundary={@object_boundary}
                object_type={e(component_assigns, :object_type, @object_type)}
                object_type_readable={e(component_assigns, :object_type_readable, @object_type_readable)}
                verb={e(component_assigns, :verb, @verb)}
                thread_id={@thread_id}
                thread_title={e(component_assigns, :thread_title, @thread_title)}
                permalink={e(component_assigns, :permalink, @permalink)}
                viewing_main_object={e(component_assigns, :viewing_main_object, @viewing_main_object)}
                activity_component_id={e(component_assigns, :activity_component_id, @activity_component_id)}
                reply_count={@reply_count}
              />
            {#match _}
              <Dynamic.Component
                :if={@hide_activity != "dynamic"}
                module={component}
                id={e(component_assigns, :id, nil)}
                myself={nil}
                created_verb_display={@created_verb_display}
                showing_within={@showing_within}
                thread_mode={debug(@thread_mode, "thread_modessss")}
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
                show_minimal_subject_and_note={e(component_assigns, :show_minimal_subject_and_note, @show_minimal_subject_and_note)}
                hide_reply={e(component_assigns, :hide_reply, @hide_reply)}
                profile={e(component_assigns, :profile, nil)}
                character={e(component_assigns, :character, nil)}
                media={e(component_assigns, :media, nil)}
                activity_component_id={e(component_assigns, :activity_component_id, @activity_component_id)}
                json={e(component_assigns, :json, nil)}
              />
          {/case}
        {/for}
      {/if}
    </article>
    """
  end

  def render(assigns) do
    warn("No activity provided")
    debug(assigns)

    ~F"""
    <div />
    """
  end

  # def show_minimal_reply?(object, activity, showing_within) do
  #   (e(object, :post_content, nil) != nil and showing_within == :smart_input) or
  #     (id(object) != nil and e(activity, :replied, :reply_to_id, nil) == nil and
  #        id(activity) == nil and showing_within != :search)
  # end

  # @decorate time()
  def component_activity_subject(
        verb,
        activity,
        object,
        object_type,
        showing_within,
        activity_inception
      )

  # don't show subject twice
  def component_activity_subject(_, _, _, Bonfire.Data.Identity.User, _, _),
    do: [Bonfire.UI.Social.Activity.SubjectMinimalLive]

  # quoting a reply_to <-- this is handled by the Bonfire.UI.Social.Activity.SubjectLive internally
  # def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]

  def component_activity_subject(verb, _activity, _, object_type, _, _)
      when verb in @react_or_simple_verbs and object_type in [Bonfire.Data.Identity.User],
      do: [
        {Bonfire.UI.Social.Activity.SubjectMinimalLive,
         %{
           verb: verb
         }}
      ]

  # reactions should show the reactor + original creator
  def component_activity_subject(verb, activity, object, object_type, _, _)
      when verb in @react_or_simple_verbs,
      do:
        [
          {Bonfire.UI.Social.Activity.SubjectMinimalLive,
           %{
             # activity: repo().maybe_preload(activity, subject: [:character]),
             verb: verb
           }}
        ] ++ component_activity_maybe_creator(activity, object, object_type)

  # replies (when shown in notifications)
  def component_activity_subject(verb, _activity, _, _, :notifications, _)
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
        _,
        _,
        _,
        _
      )
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]

  def component_activity_subject(verb, %{subject: %{profile: %{id: _} = profile}}, _, _, _, _)
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: nil}}]

  def component_activity_subject(verb, %{subject: %{character: %{id: _} = character}}, _, _, _, _)
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: nil, character: character}}]

  # other
  def component_activity_subject(_verb, activity, object, object_type, _, _),
    do:
      activity
      # |> debug("activity")
      |> component_activity_maybe_creator(object, object_type)

  # @decorate time()
  def component_activity_maybe_creator(activity, object, object_type)

  def component_activity_maybe_creator(_, _, object_type)
      when object_type in [Bonfire.Data.Identity.User],
      do: []

  #  if subject is also the creator use that
  def component_activity_maybe_creator(
        %{subject: %{id: id} = subject} = _activity,
        %{created: %{creator_id: id}} = _object,
        _
      ),
      do: component_maybe_creator(subject) || []

  def component_activity_maybe_creator(activity, object, _),
    do:
      component_maybe_creator(object) ||
        component_maybe_creator(activity) ||
        (
          debug(activity)
          debug(object)
          []
        )

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

  #  if subject is also the creator use that
  def component_maybe_creator(
        %{subject: %{id: id} = subject, created: %{creator_id: id}} = _activity
      ),
      do: component_maybe_creator(subject)

  #  if subject is also the creator use that
  def component_maybe_creator(
        %{subject: %{id: id} = subject, object: %{created: %{creator_id: id}}} = _activity
      ),
      do: component_maybe_creator(subject)

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

  def component_maybe_creator(activity_or_object) do
    warn(activity_or_object, "could not find a creator")
    nil
  end

  # @decorate time()
  def component_maybe_in_reply_to(
        verb,
        activity,
        showing_within,
        activity_inception,
        viewing_main_object,
        thread_mode,
        thread_id,
        thread_title,
        activity_component_id
      )

  def component_maybe_in_reply_to(
        _verb,
        _activity,
        showing_within,
        activity_inception,
        viewing_main_object,
        thread_mode,
        thread_id,
        thread_title,
        _activity_component_id
      )
      # cases where we do not show reply_to
      when not is_nil(activity_inception) or
             (viewing_main_object != true and showing_within in [:thread, :smart_input] and
                thread_mode != :flat),
      do: []

  def component_maybe_in_reply_to(
        verb,
        %{reply_to: %{id: reply_to_id}},
        showing_within,
        _,
        _,
        thread_mode,
        thread_id,
        _,
        _
      )
      when thread_mode == :flat and reply_to_id == thread_id and
             showing_within in [:thread, :messages],
      do: []

  def component_maybe_in_reply_to(
        verb,
        %{
          id: activity_id,
          reply_to:
            %{
              post_content: %{id: id} = reply_to_post_content,
              created: %{
                creator: %{
                  character: %{id: _} = subject_character,
                  profile: %{id: _} = subject_profile
                }
              }
            } = _reply_to
        },
        _,
        _,
        _,
        _,
        _thread_id,
        thread_title,
        activity_component_id
      )
      when verb in @reply_verbs do
    debug("we have a reply_to, preloaded with post_content")

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "reply_to-#{activity_component_id}-#{id}",
         activity_inception: activity_id,
         show_minimal_subject_and_note: name_or_text(reply_to_post_content) || true,
         viewing_main_object: false,
         thread_title: thread_title,
         object: reply_to_post_content,
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
        _,
        _,
        _,
        _,
        _thread_id,
        thread_title,
        activity_component_id
      )
      when verb in @reply_verbs and is_binary(reply_to_id) do
    debug("we have another kind of reply_to, preloaded with creator")

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "reply_to-#{activity_component_id}-#{reply_to_id}",
         activity_inception: activity_id,
         show_minimal_subject_and_note: name_or_text(replied) || true,
         viewing_main_object: false,
         thread_title: thread_title,
         object: replied,
         activity: %{
           # Activities.load_object(replied, skip_boundary_check: true),
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
              id: reply_to_id
            } = replied
        },
        _,
        _,
        _,
        _,
        _thread_id,
        thread_title,
        activity_component_id
      )
      when verb in @reply_verbs and is_binary(reply_to_id) do
    debug("we have another kind of reply_to, but no creator")

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "reply_to-#{activity_component_id}-#{reply_to_id}",
         activity_inception: activity_id,
         show_minimal_subject_and_note: name_or_text(replied) || true,
         viewing_main_object: false,
         thread_title: thread_title,
         object: replied,
         activity: %{
           # Activities.load_object(replied, skip_boundary_check: true),
           subject: nil
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
  #       _, _, _, _, _, _, _
  #     )
  #     # other kind of reply
  #     when verb in @reply_verbs and is_binary(reply_to_id) do
  #   maybe_load_in_reply_to(replied, activity_id, current_user: current_user(assigns))
  # end

  def component_maybe_in_reply_to(
        verb,
        %{replied: %{} = replied},
        showing_within,
        activity_inception,
        viewing_main_object,
        thread_mode,
        thread_id,
        thread_title,
        activity_component_id
      ),
      do:
        component_maybe_in_reply_to(
          verb,
          replied,
          showing_within,
          activity_inception,
          viewing_main_object,
          thread_mode,
          thread_id,
          thread_title,
          activity_component_id
        )

  # def component_maybe_in_reply_to(
  #       verb,
  #       %{id: object_id, thread: %{id: thread_id} = thread},
  #       _, _, _, _, _
  #     )
  #     when object_id != thread_id,
  #     do: maybe_load_in_reply_to(thread, thread_id, current_user: current_user(assigns))

  def component_maybe_in_reply_to(_, a, _, _, _, _, _, _, _) do
    debug(a, "no reply_to")
    []
  end

  def name_or_text(%{post_content: %{name: _} = post_content} = _data),
    do: name_or_text(post_content)

  def name_or_text(%{named: %{name: name}} = _data), do: name

  def name_or_text(%{name: _} = data),
    do: e(data, :name, nil) || e(data, :summary, nil) || e(data, :html_body, nil)

  def name_or_text(_data), do: nil

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
  #        id: "ra-" <> reply_to_id,
  #        activity_inception: activity_inception,
  #  show_minimal_subject_and_note: true,
  #        thread_title: thread_title,
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

  # @decorate time()
  def component_object(verb, activity, object, object_type)

  def component_object(_, _, %{post_content: %{html_body: _}}, _),
    do: [Bonfire.UI.Social.Activity.NoteLive]

  # def component_object(_, %{object: %{profile: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]
  # def component_object(_, %{object: %{character: _}}), do: [Bonfire.UI.Social.Activity.CharacterLive]

  def component_object(_, _, %{} = object, object_type) do
    case object_type || Types.object_type(object) do
      Bonfire.Data.Social.APActivity ->
        json = e(object, :json, nil)

        case String.capitalize(
               e(json, "object", "type", nil) || e(json, "type", nil) || "Remote Activity"
             ) do
          "Event" = object_type ->
            [
              {Bonfire.UI.Social.Activity.EventActivityStreamsLive,
               json: json, object_type_readable: object_type}
            ]

          object_type ->
            [
              {Bonfire.UI.Social.Activity.UnknownActivityStreamsLive,
               json: json, object_type_readable: object_type}
            ]
        end

      type when is_atom(type) and not is_nil(type) ->
        debug(type, "component object_type recognised")
        component_for_object_type(type, object)

      _ ->
        warn(
          object_type || object,
          "use UnknownLive because component object_type NOT detected"
        )

        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, _, _, _) do
    debug("activity has no object")
    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_for_object_type(type, %{post_content: %{html_body: _}})
      when type in [Bonfire.Data.Social.Post],
      do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, _object) when type in [Bonfire.Data.Social.Post],
    # for posts with no text content (eg. only with attachments)
    do: []

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.Message],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.PostContent],
    do: [Bonfire.UI.Social.Activity.NoteLive]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Identity.User],
    # do: [Bonfire.UI.Social.Activity.CharacterLive]
    do: []

  # do: [{Bonfire.UI.Social.Activity.CharacterLive, %{
  #     object: repo().maybe_preload(object, [:character, profile: :icon])
  #   }}]

  def component_for_object_type(type, _) when type in [Bonfire.Data.Social.Follow],
    # do: [Bonfire.UI.Social.Activity.CharacterLive]
    do: []

  def component_for_object_type(type, _) when type in [:group],
    do: [Bonfire.UI.Social.Activity.GroupLive]

  def component_for_object_type(type, _) when type in [:topic, Bonfire.Classify.Category],
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
    warn("no component set up for object_type: #{inspect(type)}, fallback to UnknownLive")

    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  def component_maybe_attachments(files)
      when is_list(files) and files != [] do
    debug(files, "has files")

    [
      {Bonfire.UI.Social.Activity.MediaLive, %{media: files}}
    ]
  end

  def component_maybe_attachments(other) do
    debug(other, "no files")
    []
  end

  # @decorate time()
  def component_actions(
        verb,
        activity,
        object_type,
        showing_within,
        activity_inception,
        viewing_main_object
      )

  # don't show any
  def component_actions(_, _, _, _, activity_inception, _)
      when not is_nil(activity_inception),
      do: []

  def component_actions(_, _, _, showing_within, _, _)
      when showing_within == :smart_input,
      do: []

  # WIP: THIS NEEDS TO BE REFACTORED ACCORDING TO actions_for_object_type
  def component_actions("Flag", _, _, _, _, _), do: [Bonfire.UI.Social.FlaggedActionsLive]

  # def component_actions(_, activity, _, _, _, true) do
  #   [Bonfire.UI.Social.Activity.MainObjectInfoLive] ++ component_actions(nil, activity, nil)
  # end

  def component_actions(_, activity, object_type, _, _, _) do
    actions_for_object_type(activity, object_type)
  end

  def component_actions(_, _, _, _, _, _), do: []

  # WIP: Customize actions for each activity type
  def actions_for_object_type(_activity, type)
      when type in [Bonfire.Data.Identity.User, Bonfire.Data.Identity.Character],
      do: []

  def actions_for_object_type(_activity, type) when type in [Bonfire.Data.Social.Flag], do: []

  def actions_for_object_type(activity, type)
      when type in [Bonfire.Data.Social.Post, Bonfire.Data.Social.PostContent],
      do: component_show_standard_actions(activity)

  # def actions_for_object_type(activity, type)
  #     when type in [Bonfire.Classify.Category],
  #     do: component_show_category_actions(activity)
  def actions_for_object_type(_activity, type)
      when type in [Bonfire.Classify.Category],
      do: []

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicEvent],
  #   do: component_show_event_actions(activity)

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicResource],
  #   do: component_show_process_actions(activity)

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(_activity, type) when type in [ValueFlows.Planning.Intent],
    do: []

  # TODO: choose between Task and other Intent types
  def actions_for_object_type(_activity, type) when type in [ValueFlows.Process],
    do: []

  def actions_for_object_type(activity, type) do
    debug(type, "No specific actions defined fot this type")
    component_show_standard_actions(activity)
    # [Bonfire.UI.Social.Activity.NoActionsLive]
  end

  # |> debug
  def component_show_standard_actions(
        %{subject: %{character: %{username: _username}}} = _activity
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
