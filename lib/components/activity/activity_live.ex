defmodule Bonfire.UI.Social.ActivityLive do
  use Bonfire.UI.Common.Web, :stateful_component
  use Untangle

  alias Bonfire.Social.Activities
  # alias Bonfire.Data.Social.Activity
  alias Bonfire.Social.Feeds.LiveHandler
  import Phoenix.LiveView.JS

  # TODO: autogenerate with Verbs genserver?
  @reply_verbs Application.compile_env(:bonfire, [:verb_families, :reply]) || ["Respond"]
  @create_verbs Application.compile_env(:bonfire, [:verb_families, :create]) || ["Write", "Send"]
  @react_verbs (Application.compile_env(:bonfire, [:verb_families, :react]) || []) ++ ["React"]
  @simple_verbs Application.compile_env(:bonfire, [:verb_families, :simple_action]) || []
  @react_or_request_verbs @react_verbs
  @react_or_simple_verbs @react_verbs ++ @simple_verbs
  # @react_or_reply_verbs @react_verbs ++ @reply_verbs
  @create_or_reply_verbs @create_verbs ++ @reply_verbs
  @created_verb_display Activities.verb_display("Create")

  prop activity, :any, default: nil
  prop activity_id, :string, default: nil
  prop object, :any, default: nil
  prop object_id, :string, default: nil
  prop object_type, :any, default: nil
  prop verb, :string, default: nil
  prop verb_default, :string, default: nil
  prop verb_display, :string, default: nil
  prop date_ago, :any, default: nil
  prop feed_id, :any, default: nil
  prop feed_name, :any, default: nil
  prop activity_component_id, :any, default: nil
  prop parent_id, :any, default: nil
  prop activity_inception, :any, default: nil
  prop activity_prepared, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :any, default: nil
  prop highlight_activity_id, :any, default: nil
  prop hide_reply, :boolean, default: false
  prop class, :string, required: false, default: ""
  prop thread_id, :string, default: nil
  prop thread_object, :any, default: nil
  prop thread_url, :string, default: nil
  prop thread_title, :string, default: nil
  prop thread_mode, :any, default: nil
  prop thread_level, :any, default: nil
  prop current_url, :string, default: nil
  prop permalink, :string, default: nil
  prop participants, :any, default: nil
  prop object_boundary, :any, default: nil
  prop cw, :any, default: nil
  prop emoji, :any, default: nil
  prop check_object_boundary, :boolean, default: false
  prop is_remote, :any, default: nil
  prop show_minimal_subject_and_note, :any, default: false
  prop hide_activity, :any, default: nil
  prop i, :integer, default: nil
  prop created_verb_display, :string, default: @created_verb_display
  prop object_type_readable, :string, default: nil
  prop reply_count, :any, default: nil
  prop reply_to, :any, default: nil
  prop published_in, :any, default: nil
  prop labelled, :any, default: nil
  prop subject_user, :any, default: nil
  prop peered, :any, default: nil
  prop hide_actions, :any, default: false
  prop activity_preloads, :tuple, default: {nil, nil}
  prop custom_preview, :any, default: nil
  prop quotes, :list, default: []

  def update_many(assigns_sockets) do
    assigns_sockets
    |> LiveHandler.activity_update_many(caller_module: __MODULE__)
    |> debug("activity_updated_many")
    |> Enum.map(fn
      {assigns, socket} ->
        maybe_update(assigns, socket)

      socket ->
        maybe_update(assigns(socket), socket)
    end)
  end

  defp debug_i(i, activity_inception), do: i || "inception-from-#{activity_inception}"

  def maybe_update(%{activity_remove: true}, socket) do
    remove(socket)
  end

  def maybe_update(
        %{preloaded_async_activities: preloaded_async_activities, activity: activity} = assigns,
        %{assigns: %{activity_prepared: true}} = socket
      )
      when is_map(activity) and preloaded_async_activities == true do
    debug(
      "Activity ##{debug_i(assigns(socket)[:activity_id], assigns(socket)[:activity_inception])} prepared already, just assign updated activity"
    )

    # debug(assigns)

    assign(
      socket,
      activity: if(is_map(activity), do: Map.delete(activity, :object)),
      object: e(activity, :object, nil)
    )
    |> maybe_update_some_assigns(assigns, [])
  end

  def maybe_update(
        %{update_activity: true} = assigns,
        socket
      ) do
    debug("Activity - assigns with `update_activity` so we update them")

    socket
    |> assign(assigns)
    |> maybe_update_some_assigns(assigns, [])
  end

  def maybe_update(
        %{object_boundary: object_boundary} = _assigns,
        %{assigns: %{activity_prepared: true}} = socket
      )
      when not is_nil(object_boundary) do
    debug(
      "Activity ##{debug_i(assigns(socket)[:activity_id], assigns(socket)[:activity_inception])} prepared already, just assign object_boundary"
    )

    socket
    |> assign(object_boundary: object_boundary)
  end

  def maybe_update(assigns, %{assigns: %{activity_prepared: true}} = socket) do
    debug(
      "Activity ##{debug_i(assigns[:activity_id] || assigns(socket)[:activity_id], assigns[:activity_inception] || assigns(socket)[:activity_inception])} prepared already"
    )

    # FYI: assigning blindly here causes problems
    socket
    |> maybe_update_some_assigns(assigns, [])
  end

  def maybe_update(assigns, socket) do
    debug(
      "Activity ##{debug_i(assigns[:activity_id] || assigns(socket)[:activity_id], assigns[:activity_inception] || assigns(socket)[:activity_inception])} not prepared, do so now"
    )

    socket
    |> assign(prepare_assigns(assigns) |> assigns_clean())
  end

  def maybe_update_some_assigns(socket \\ nil, assigns, extras) do
    socket
    |> assign(prepare_mutable_assigns(socket, assigns, extras) |> assigns_clean())
  end

  defp prepare_mutable_assigns(socket \\ %{}, assigns, extras)

  defp prepare_mutable_assigns(
         %Phoenix.LiveView.Socket{assigns: socket_assigns},
         assigns,
         extras
       ),
       do: prepare_mutable_assigns(socket_assigns, assigns, extras)

  defp prepare_mutable_assigns(socket_assigns, assigns, extras) do
    activity =
      (assigns[:activity] || socket_assigns[:activity])
      |> debug("the activity")

    object = assigns[:object] || e(activity, :object, nil) || socket_assigns[:object]

    showing_within =
      case e(assigns, :showing_within, nil) do
        nil -> e(socket_assigns, :showing_within, nil)
        existing -> existing
      end || :feed

    verb = extras[:verb] || prepare_verb(activity, e(assigns, :verb_default, nil) || "Create")

    created =
      e(object, :created, nil) ||
        e(activity, :created, nil)

    peered =
      e(object, :peered, nil) ||
        e(created, :creator, :character, :peered, nil) ||
        if id(object) == id(activity) do
          e(activity, :peered, nil)
        end ||
        if is_nil(created) or e(created, :creator_id, nil) == e(activity, :subject_id, nil) do
          e(activity, :subject, :character, :peered, nil)
        end

    # |> debug("peeeered")

    [
      showing_within: showing_within,
      verb: verb,
      thread_mode:
        case e(assigns, :thread_mode, nil) do
          nil -> e(socket_assigns, :thread_mode, nil)
          existing -> existing
        end,
      published_in: maybe_published_in(activity, verb),
      labelled: maybe_labelled(activity, verb),
      peered: peered,
      is_remote:
        (assigns[:is_remote] ||| socket_assigns[:is_remote] |||
           !Bonfire.Social.is_local?(
             peered ||
               e(activity, :subject, nil) ||
               e(assigns, :subject_user, nil) ||
               e(socket_assigns, :subject_user, nil),
             false
           ))
        |> debug("is_remote"),
      thread_title:
        e(assigns, :thread_title, nil) || e(socket_assigns, :thread_title, nil) ||
          e(extras[:thread], :named, :name, nil) ||
          e(activity, :replied, :thread, :named, :name, nil) ||
          e(activity, :named, :name, nil) ||
          e(object, :named, :name, nil),
      hide_actions:
        case e(assigns, :hide_actions, nil) || e(socket_assigns, :hide_actions, nil) do
          nil ->
            (!(e(assigns, :viewing_main_object, nil) ||
                 e(socket_assigns, :viewing_main_object, nil)) and
               Settings.get(
                 [
                   Bonfire.UI.Social.Activity.ActionsLive,
                   showing_within,
                   :hide_until_hovered
                 ],
                 nil,
                 current_user(assigns) || current_user(socket_assigns)
               )) && "until_hovered"

          hide_actions ->
            hide_actions
        end
    ]

    # |> debug("sooaa")
  end

  # def assigns_from_activity(activity) do
  #   # TODO: use this also in `prepare_assigns` to avoid duplication
  #   %{
  #     activity: if(is_map(activity), do: Map.drop(activity, [:object])),
  #     object: e(activity, :object, nil),
  #     # object_type: Types.object_type(list_of_activities[component.object_id]) || component.object_type
  #     published_in: maybe_published_in(activity, nil),
  #     is_remote:
  #         (e(activity, :peered, nil) != nil or
  #            e(activity, :object, :peered, nil) != nil),
  #     thread_title:
  #        e(activity, :replied, :thread, :named, :name, nil)
  #   }
  # end

  def remove(socket) do
    assign(
      socket,
      hide_activity: "all",
      activity: %{},
      object: %{}
    )
  end

  @decorate time()
  def prepare_assigns(assigns)

  def prepare_assigns(%{activity: _, object: %{}} = assigns) do
    do_prepare_assigns(assigns)
  end

  def prepare_assigns(%{activity: %{object: object} = activity, object: nil} = assigns)
      when not is_nil(object) do
    debug(
      "Activity ##{debug_i(assigns[:activity_id] || id(assigns[:activity]), assigns[:activity_inception])} prepare_assigns activity with object in assoc"
    )

    Map.put(assigns, :object, object)
    |> Map.put(:activity, Map.delete(activity, :object))
    |> do_prepare_assigns()
  end

  def prepare_assigns(%{activity: %{object: object} = activity} = assigns)
      when not is_nil(object) do
    assigns
    |> Map.put(:object, object)
    |> Map.put(:activity, Map.delete(activity, :object))
    |> do_prepare_assigns()
  end

  def prepare_assigns(assigns), do: Map.put(assigns, :activity_prepared, :skipped)

  defp do_prepare_assigns(%{activity: activity, object: object} = assigns)
       when not is_nil(object) do
    activity_inception = e(assigns, :activity_inception, nil)

    # debug("Activity ##{debug_i(assigns[:activity_id], activity_inception)} preparation started")
    # debug(assigns, "initial assigns")

    # debug(object, "object")

    verb = prepare_verb(activity, e(assigns, :verb_default, nil) || "Create")

    # |> debug("verb (modified)")

    replied =
      e(activity, :replied, nil) ||
        e(object, :replied, nil)
        |> debug("areplied")

    thread_level = e(assigns, :thread_level, nil) || length(e(replied, :path, []))

    thread =
      e(assigns, :thread_object, nil) || e(replied, :thread, nil) || e(replied, :thread_id, nil) ||
        e(assigns, :thread_id, nil)

    reply_to = if verb in @reply_verbs, do: prepare_reply_to(replied || activity)

    verb_display = Activities.verb_display(verb)

    object_type =
      assigns[:object_type] || Types.object_type(object)

    object_type =
      cond do
        is_article?(object_type, object) -> :article
        true -> object_type
      end
      |> debug("object_type!!")

    object_type_readable =
      assigns[:object_type_readable] ||
        cond do
          object_type == Bonfire.Data.Social.Post and not is_nil(reply_to) ->
            l("comment")

          object_type == :article ->
            l("article")

          true ->
            Types.object_type_display(object_type)
        end

    thread_id = id(thread)
    # debug(thread, "thread")
    thread_url =
      e(assigns, :thread_url, nil) ||
        if not is_nil(thread) do
          if is_struct(thread) do
            path(thread, [], preload_if_needed: false)
          else
            "/discussion/#{thread_id}"
          end
        end

    # debug(activity, "theactivity")

    object_id = id(object)
    a_id = id(activity) || object_id
    o_id = object_id || a_id

    current_url =
      (assigns[:current_url] || current_url(assigns[:__context__]))
      |> debug("activity_current_url")

    # permalink = path(object, [], preload_if_needed: false)
    permalink =
      cond do
        thread_url && thread_id != o_id ->
          if thread_level != 0 do
            "#{thread_url}/reply/#{thread_level}/#{o_id}"
          else
            "#{thread_url}/reply/#{o_id}"
          end

        true ->
          "#{path(object, [], preload_if_needed: false)}#"
      end
      |> String.trim_leading("#{current_url || "#"}#")

    # |> debug()

    activity_component_id =
      Enums.id(assigns) || assigns[:activity_component_id] ||
        deterministic_dom_id(
          __MODULE__,
          a_id || "no-activity-id",
          activity_inception,
          e(assigns, :parent_id, nil)
        )

    assigns
    |> prepare_mutable_assigns(
      verb: verb,
      thread: thread
    )
    |> Enum.into(debug(assigns, "original passed assigns"))
    |> Map.merge(%{
      activity_prepared: true,
      activity_id: a_id || "no-activity-id",
      object_id: o_id || "no-object-id",
      activity_component_id: activity_component_id,
      reply_to: reply_to,
      object_type: object_type,
      object_type_readable: object_type_readable,
      # unit: :minute
      # NOTE: skip narrow format which gives odd results in some languages
      date_ago:
        if(
          e(assigns[:__context], :ui_compact, nil) &&
            Bonfire.Common.Localise.get_locale_id() not in [:fr],
          do: DatesTimes.date_from_now(object_id, format: :narrow),
          else: DatesTimes.date_from_now(object_id)
        ),
      verb: verb,
      verb_display: verb_display,
      created_verb_display: e(assigns, :created_verb_display, nil),
      permalink: permalink,
      thread_url: thread_url,
      current_url: current_url,
      thread_id: thread_id,
      thread_level: thread_level,
      quotes: Bonfire.Social.Tags.tags_quote(activity),
      cw:
        if e(assigns, :activity_inception, nil) do
          # This may be a reply_to, calculate CW based on reply_to data structure
          sensitive?(activity)

          # || e(object, :summary, nil) != nil  <-- summary is not a replacement for CW now that we include article objects
        else
          # For regular activities, calculate CW normally
          e(assigns, :cw, nil) ||
            sensitive?(activity)

          #  || e(object, :post_content, :summary, nil) != nil <-- summary is not a replacement for CW now that we include article objects
        end,
      reply_count: e(replied, :nested_replies_count, 0) + e(replied, :direct_replies_count, 0),
      parent_id:
        "#{activity_component_id}_#{e(assigns, :showing_within, nil)}_#{activity_inception}"
    })

    # |> debug("Activity preparation done")
  end

  defp do_prepare_assigns(assigns), do: Map.put(assigns, :activity_prepared, :skipped)

  defp prepare_verb(activity, fallback \\ nil)

  defp prepare_verb(%{emoji: %{media_type: "emoji"}}, fallback) do
    "React"
  end

  defp prepare_verb(%{emoji: %{summary: _}}, fallback) do
    "React"
  end

  defp prepare_verb(activity, fallback) do
    # Debug the activity structure to understand what's available
    # debug(e(activity, :verb, nil), "prepare_verb: activity.verb")
    # debug(e(activity, :verb_id, nil), "prepare_verb: activity.verb_id")
    # debug(e(activity, :table_id, nil), "prepare_verb: activity.table_id")
    # debug(e(activity, :__struct__, nil), "prepare_verb: activity.__struct__")
    # debug(e(activity, :edge, nil), "prepare_verb: activity.edge")

    # Extract verb string from nested structure if present
    raw_verb =
      e(activity, :verb, :verb, nil) || e(activity, :verb, nil) || e(activity, :verb_id, nil)

    # |> debug("prepare_verb: raw verb before modification")

    Activities.verb_maybe_modify(raw_verb || fallback, activity)
    |> debug("prepare_verb: final verb after verb_maybe_modify")
  end

  # defp derive_verb_from_table_id(%{table_id: "300STANN0VNCERESHARESH0VTS"}), do: "Boost"
  # defp derive_verb_from_table_id(%{table_id: "61KESLYKL1KE1Y0VL1KESTH1S"}), do: "Like"
  # defp derive_verb_from_table_id(_), do: nil

  defp sensitive?(activity) do
    case Map.get(activity, :sensitive) do
      nil ->
        false

      %Ecto.Association.NotLoaded{} ->
        # Default to nil when sensitive field is not preloaded
        # This should never be the case though so let's fail in test env
        err(activity, "Sensitive field not preloaded for activity")

        nil

      %{is_sensitive: is_sensitive} when is_boolean(is_sensitive) or is_nil(is_sensitive) ->
        is_sensitive

      bool when is_boolean(bool) ->
        bool

      other ->
        err(other, "Sensitive assoc returned something unexpected")
        nil
    end
  end

  def maybe_published_in(%{subject: %{table_id: "2AGSCANBECATEG0RY0RHASHTAG"} = subject}, "Boost") do
    subject
  end

  def maybe_published_in(%{tree: %{parent: %{id: _} = parent}}, _) do
    parent
  end

  def maybe_published_in(%{tree: %{parent_id: parent_id}}, _) do
    parent_id
  end

  def maybe_published_in(_none, _verb) do
    # debug(none, "none for #{verb}")
    nil
  end

  def maybe_labelled(%{labelled: %{subject: %{} = label} = _labelled}, _) do
    label
  end

  def maybe_labelled(%{labelled: %{id: _} = labelled}, _) do
    labelled
  end

  def maybe_labelled(%{subject: %{table_id: "2AGSCANBECATEG0RY0RHASHTAG"} = subject}, "Label") do
    subject
  end

  def maybe_labelled(_none, _verb) do
    # debug(none, "none for #{verb}")
    nil
  end

  def activity_components(
        activity,
        verb,
        object_override,
        showing_within
      ) do
    object = object_override || e(activity, :object, nil)

    replied =
      e(activity, :replied, nil) ||
        e(object, :replied, nil)

    thread =
      e(replied, :thread, nil) || e(replied, :thread_id, nil)

    reply_to = if verb in @reply_verbs, do: prepare_reply_to(replied || activity)

    activity_components(
      activity,
      verb,
      object,
      Types.object_type(object),
      false,
      showing_within,
      false,
      nil,
      id(thread),
      nil,
      nil,
      nil,
      reply_to,
      []
    )
  end

  def activity_components(
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
        activity_component_id,
        subject_user,
        reply_to,
        quotes
      ) do
    {primary_image, attachments_component} =
      primary_image_and_component_maybe_attachments(
        object_type,
        activity,
        object,
        activity_inception
      )

    (if(showing_within == :media, do: attachments_component, else: []) ++
       component_maybe_in_reply_to(
         reply_to,
         showing_within,
         activity_inception,
         viewing_main_object,
         thread_mode,
         thread_id,
         thread_title,
         activity_component_id
       ) ++
       (component_activity_subject(
          verb,
          activity,
          object,
          object_type,
          showing_within,
          activity_inception,
          subject_user
        )
        |> debug("component_activity_subject result")) ++
       component_maybe_quote_post(activity_component_id, quotes) ++
       component_object(object, object_type, %{primary_image: primary_image}) ++
       if(showing_within != :media, do: attachments_component, else: []) ++
       component_actions(
         verb,
         activity,
         object_type,
         showing_within,
         activity_inception,
         viewing_main_object
       ))
    |> debug("preview_components unfiltered - #{activity_inception}")
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn
      c when is_atom(c) -> {c, nil}
      other -> other
    end)
    |> debug("preview_components - #{activity_inception}")
  end

  def maybe_prepare(%{activity: _, activity_prepared: true} = assigns) do
    assigns
  end

  def maybe_prepare(%{activity: _} = assigns) do
    prepare_assigns(assigns)
  end

  def render(%{activity: _} = assigns) do
    assigns =
      if assigns[:activity_prepared] == :defer_to_render,
        do: maybe_prepare(assigns),
        else: assigns

    ~F"""
    <article
      id={@activity_component_id || "activity-unprepared-#{@activity_id || Text.random_string()}"}
      data-content-open={!@cw}
      data-object_id={@object_id}
      data-href={@permalink}
      data-url={@current_url}
      phx-hook={if @highlight_activity_id == @activity_id, do: "ScrollTo", else: (if !@viewing_main_object and
           @showing_within not in [:thread, :smart_input, :widget],
         do: "Bonfire.UI.Common.PreviewContentLive#PreviewActivity")}
      role="article"
      data-id="activity"
      data-rendered={@showing_within}
      data-avatar-hidden={Media.hide_avatars?(@__context__, @showing_within)}
      data-hidden={@hide_activity}
      data-compact={@__context__[:ui_compact]}
      data-answer={not is_nil(e(@activity, :replied, :pinned, nil) || e(@activity, :pinned, nil))}
      data-verb={@verb}
      aria-label="user activity"
      tabIndex="0"
      class={
        "p-5 activity-padding activity relative flex flex-col gap-1 #{@class}",
        "hover:bg-primary hover:bg-opacity-5":
          @showing_within not in [:thread, :smart_input, :widget] && !@activity_inception,
        "replied !p-0 mb-8":
          @activity_inception &&
            @showing_within not in [:smart_input, :thread, :quote_preview, :quote_post, :nested_preview],
        "unread-activity":
          is_nil(e(@activity, :seen, nil)) and @showing_within == :notifications and
            is_nil(@activity_inception),
        "active-activity":
          @highlight_activity_id == @activity_id and
            @showing_within != :smart_input and @viewing_main_object == false
      }
      
    >
      {#if @custom_preview}
        <StatelessComponent
          permalink={@permalink}
          reply_count={@reply_count}
          date_ago={@date_ago}
          object={@object}
          activity={@activity}
          activity_component_id={@activity_component_id}
          is_remote={@is_remote}
          module={maybe_component(@custom_preview, @__context__)}
        />
      {#else}
        {#if @hide_activity != "all"}
          {#if current_user_id(@__context__) && @showing_within != :smart_input}
            {#case is_nil(@thread_id) or @thread_id == (@object_id || @activity_id)}
              {#match top_of_thread?}
                {#case not is_nil(@thread_id) and @thread_id == e(@reply_to, :object, :id, nil)}
                  {#match reply_to_top_of_thread?}
                    {!-- TODO: make the list of preview paths/components/views configurable/hookable, and derive the view from object_type? and compute object_type not just based on schema, but also with some logic looking at fields (eg. action=="work") --}
                    {#if String.starts_with?(@permalink || "", ["/post/", "/discussion/"])}
                      <Bonfire.UI.Common.OpenPreviewLive
                        href={@permalink}
                        parent_id={@activity_component_id}
                        open_btn_text=""
                        title_text={@thread_title || e(@object, :name, nil) || e(@object, :post_content, :name, nil) ||
                          l("Discussion")}
                        modal_assigns={
                          post_id:
                            if(
                              @object_type in [Bonfire.Data.Social.Post, :article] or
                                String.starts_with?(@permalink || "", ["/post/"]),
                              do: @thread_id || @object_id
                            ),
                          thread_id: @thread_id,
                          object_id: @thread_id || @object_id,
                          reply_id: @object_id,
                          include_path_ids:
                            e(
                              e(@activity, :replied, nil) ||
                                e(@object, :replied, nil),
                              :path,
                              []
                            ) ++ [@object_id],
                          # ^ tells the comments loader to include the ancestors of the object regardless of max depth
                          current_url: @permalink,
                          show: true,
                          hide_actions: false,
                          cw: false,
                          label: "",
                          object:
                            cond do
                              top_of_thread? -> @object
                              reply_to_top_of_thread? -> e(@reply_to, :object, nil)
                              true -> nil
                            end,
                          activity:
                            cond do
                              top_of_thread? -> @activity
                              reply_to_top_of_thread? -> e(@reply_to, :activity, nil)
                              true -> nil
                            end,
                          replies:
                            cond do
                              top_of_thread? ->
                                nil

                              reply_to_top_of_thread? ->
                                [%{id: "preview-comment", activity: Map.put(@activity, :object, @object)}]

                              true ->
                                [
                                  %{
                                    id: "preview-comment-reply_to",
                                    activity: Map.put(e(@reply_to, :activity, %{}), :object, e(@reply_to, :object, nil)),
                                    replies: [
                                      %{
                                        id: "preview-comment-reply",
                                        activity:
                                          Map.put(if(is_map(@activity), do: @activity, else: %{}), :object, @object)
                                      }
                                    ]
                                  }
                                ]
                            end,
                          modal_component: Bonfire.UI.Social.ObjectThreadLive,
                          modal_component_stateful?: !top_of_thread? and !reply_to_top_of_thread?,
                          loaded: true,
                          activity_inception: "preview",
                          showing_within: :thread,
                          check_object_boundary: !top_of_thread? and !reply_to_top_of_thread?
                        }
                        root_assigns={
                          page_title: l("Discussion")
                        }
                      />
                    {#elseif String.starts_with?(@permalink || "", ["/@", "/profile/", "/user"])}
                      {!-- <Bonfire.UI.Common.OpenPreviewLive
              href={@permalink}
              parent_id={@activity_component_id}
              open_btn_text={l("View profile")}
              title_text={e(@object, :profile, :name, nil) || l("Profile")}
              modal_assigns={
                id: @thread_id || @object_id,
                current_url: @permalink,
                modal_view: Bonfire.UI.Me.ProfileLive,
                activity_inception: "preview"
              }
              root_assigns={
                page_title: l("Profile")
              }
            />
             --}
                    {#elseif String.starts_with?(@permalink || "", ["/coordination/task/"]) and
                        module_enabled?(Bonfire.UI.Coordination.TaskLive)}
                      <Bonfire.UI.Common.OpenPreviewLive
                        href={@permalink}
                        parent_id={@activity_component_id}
                        open_btn_text={l("View task")}
                        title_text={e(@object, :name, nil) || l("Task")}
                        modal_assigns={
                          id: @thread_id || @object_id,
                          current_url: @permalink,
                          modal_view: Bonfire.UI.Coordination.TaskLive,
                          activity_inception: "preview",
                          check_object_boundary: false,
                          loaded: true
                        }
                        root_assigns={
                          page_title: l("Task")
                        }
                      />
                    {/if}
                {/case}
            {/case}
          {/if}

          <form
            :if={!id(e(@activity, :seen, nil)) and not is_nil(@feed_id) and
              @showing_within in [:messages, :thread, :notifications] and
              current_user_id(@__context__) != ( e(@object, :created, :creator_id, nil) || e(@activity, :subject, :id, nil) )}
            x-init="
              if ($el.getBoundingClientRect().top < window.innerHeight && $el.getBoundingClientRect().bottom > 0) {
                $el.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));
                $el.parentNode.classList.remove('unread-activity');
              }
            "
            x-intersect.once.full="$el.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true})); $el.parentNode.classList.remove('unread-activity');"
            phx-submit={if @feed_id, do: "Bonfire.Social.Feeds:mark_seen"}
            phx-target={if @feed_id, do: "#badge_counter_#{@feed_id}"}
          >
            <input type="hidden" name="feed_id" value={@feed_id}>
            <input type="hidden" name="activity_id" value={@activity_id}>
          </form>

          <Bonfire.UI.Social.Activity.PublishedInLive
            :if={@published_in && @showing_within != :smart_input}
            context={@published_in}
            showing_within={@showing_within}
          />

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
                @activity_component_id,
                @subject_user,
                @reply_to,
                @quotes
              ) || []}
            {#case component}
              {#match :html}
                {raw(component_assigns)}
              {#match _
                when component in [
                       Bonfire.UI.Social.Activity.SubjectLive,
                       Bonfire.UI.Social.Activity.SubjectMinimalLive,
                       Bonfire.UI.Social.Activity.NoSubjectLive
                     ]}
                <StatelessComponent
                  :if={@hide_activity != "subject"}
                  module={component}
                  path={case maybe_get(component_assigns, :character, nil) do
                    nil -> 
                      maybe_get(component_assigns, :subject_id, nil) 
                    character -> character
                  end                    
                  |> path([], preload_if_needed: false)
}
                  profile={maybe_get(component_assigns, :profile, nil)}
                  profile_id={id(maybe_get(component_assigns, :profile, nil))}
                  profile_media={Media.avatar_url(maybe_get(component_assigns, :profile, nil))}
                  profile_summary={e(component_assigns, :profile, :summary, nil)}
                  profile_name={e(
                    component_assigns,
                    :profile,
                    :name,
                    if(component != Bonfire.UI.Social.Activity.NoSubjectLive and @showing_within != :search,
                      do: :nil!
                    )
                  )}
                  character_username={e(component_assigns, :character, :username, nil)}
                  activity_id={id(
                    maybe_get(component_assigns, :activity, @activity)
                    |> debug("activity used in ActivityLive")
                  )}
                  object_id={id(
                    maybe_get(component_assigns, :object, @object)
                    |> debug("object used in ActivityLive")
                  )}
                  subject_id={maybe_get(component_assigns, :subject_id, nil) ||
                    e(maybe_get(component_assigns, :activity, @activity), :subject_id, nil)}
                  subjects_more={maybe_get(component_assigns, :subjects_more, [])}
                  replies_more_count={e(maybe_get(component_assigns, :activity, @activity), :replies_more_count, 0)}
                  subject_peered={e(component_assigns, :character, :peered, nil) ||
                    e(maybe_get(component_assigns, :activity, @activity), :subject, :character, :peered, nil)}
                  object_boundary={@object_boundary}
                  object_type={maybe_get(component_assigns, :object_type, @object_type)}
                  date_ago={maybe_get(component_assigns, :date_ago, @date_ago)}
                  permalink={maybe_get(component_assigns, :permalink, @permalink)}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  activity_component_id={maybe_get(component_assigns, :activity_component_id, @activity_component_id)}
                  activity_inception={maybe_get(component_assigns, :activity_inception, @activity_inception)}
                  showing_within={@showing_within}
                  parent_id={@activity_component_id}
                  thread_id={@thread_id}
                  published_in={@published_in}
                  verb={maybe_get(component_assigns, :verb, @verb)}
                  verb_display={maybe_get(component_assigns, :verb_display, @verb_display)}
                  emoji={@emoji || e(maybe_get(component_assigns, :activity, @activity), :emoji, nil)}
                  reply_to_id={e(@activity, :replied, :reply_to_id, nil)}
                  peered={@peered}
                  is_remote={@is_remote}
                  thread_title={maybe_get(component_assigns, :thread_title, @thread_title)}
                  subject_user={@subject_user}
                  show_minimal_subject_and_note={maybe_get(component_assigns, :show_minimal_subject_and_note, @show_minimal_subject_and_note)}
                  request={e(maybe_get(component_assigns, :activity, @activity), :edge, :request, nil)}
                  extra_info={e(@object, :extra_info, nil)}
                />
              {#match Bonfire.UI.Social.Activity.NoteLive}
                <Bonfire.UI.Social.Activity.NoteLive
                  :if={@hide_activity != "note"}
                  showing_within={@showing_within}
                  parent_id={@activity_component_id}
                  activity_inception={@activity_inception}
                  activity_component_id={maybe_get(component_assigns, :activity_component_id, @activity_component_id)}
                  activity={maybe_get(component_assigns, :activity, @activity)}
                  object={maybe_get(component_assigns, :object, @object)}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  cw={@cw}
                  thread_title={@thread_title}
                  is_remote={@is_remote}
                  hide_actions={@hide_actions}
                />
              {#match Bonfire.UI.Social.Activity.ArticleLive}
                <Bonfire.UI.Social.Activity.ArticleLive
                  :if={@hide_activity != "article"}
                  __context__={@__context__}
                  showing_within={@showing_within}
                  parent_id={@activity_component_id}
                  activity_inception={@activity_inception}
                  activity_component_id={maybe_get(component_assigns, :activity_component_id, @activity_component_id)}
                  activity={maybe_get(component_assigns, :activity, @activity)}
                  object={maybe_get(component_assigns, :object, @object)}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  cw={@cw}
                  thread_title={@thread_title}
                  is_remote={@is_remote}
                  hide_actions={@hide_actions}
                  primary_image={maybe_get(component_assigns, :primary_image, nil)}
                />
              {#match _
                when component in [
                       Bonfire.UI.Social.Activity.UnknownLive,
                       Bonfire.UI.Social.Activity.UnknownActivityStreamsLive,
                       Bonfire.UI.Social.Activity.AudioActivityStreamsLive,
                       Bonfire.UI.Social.Activity.VideoActivityStreamsLive
                     ]}
                <StatelessComponent
                  module={component}
                  __context__={@__context__}
                  showing_within={@showing_within}
                  parent_id={@activity_component_id}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  activity={maybe_get(component_assigns, :activity, @activity)}
                  object={maybe_get(component_assigns, :object, @object)}
                  object_type={maybe_get(component_assigns, :object_type, @object_type)}
                  object_type_readable={maybe_get(component_assigns, :object_type_readable, @object_type_readable)}
                  json={maybe_get(component_assigns, :json, nil)}
                />
              {#match Bonfire.UI.Social.Activity.MediaSkeletonLive}
                <Bonfire.UI.Social.Activity.MediaSkeletonLive
                  __context__={@__context__}
                  showing_within={@showing_within}
                  activity_inception={@activity_inception}
                  viewing_main_object={@viewing_main_object}
                  {...component_assigns || []}
                />
              {#match Bonfire.UI.Social.Activity.MediaLive}
                <Bonfire.UI.Social.Activity.MediaLive
                  :if={@hide_activity != "media"}
                  __context__={@__context__}
                  parent_id={@activity_component_id}
                  activity_inception={@activity_inception}
                  showing_within={maybe_get(component_assigns, :showing_within, @showing_within)}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  media={maybe_get(component_assigns, :media, [])}
                  cw={@cw}
                />
              {#match _
                when component in [
                       Bonfire.UI.Social.Activity.ActionsLive,
                       Bonfire.UI.Moderation.FlaggedActionsLive
                     ]}
                {#if @hide_activity != "actions" and @hide_actions != true}
                  {#if user_socket_connected?(@__context__) &&
                      LiveHandler.feed_live_update_many_preload_mode() == :async_actions}
                    <StatefulComponent
                      id={"#{@activity_component_id}_actions"}
                      module={component}
                      __context__={@__context__}
                      showing_within={@showing_within}
                      feed_name={@feed_name}
                      feed_id={@feed_id}
                      thread_mode={@thread_mode}
                      activity={maybe_get(component_assigns, :activity, @activity)}
                      object={maybe_get(component_assigns, :object, @object)}
                      object_boundary={maybe_get(component_assigns, :object_boundary, @object_boundary)}
                      object_type={maybe_get(component_assigns, :object_type, @object_type)}
                      object_type_readable={maybe_get(component_assigns, :object_type_readable, @object_type_readable)}
                      verb={maybe_get(component_assigns, :verb, @verb)}
                      thread_id={@thread_id}
                      thread_title={maybe_get(component_assigns, :thread_title, @thread_title)}
                      permalink={maybe_get(component_assigns, :permalink, @permalink)}
                      viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                      activity_component_id={maybe_get(component_assigns, :activity_component_id, @activity_component_id)}
                      parent_id={@activity_component_id}
                      published_in={@published_in}
                      labelled={@labelled}
                      reply_count={@reply_count}
                      is_remote={@is_remote}
                      is_answer={not is_nil(e(@activity, :replied, :pinned, nil) || e(@activity, :pinned, nil))}
                      hide_actions={@hide_actions}
                      subject_user={@subject_user}
                      creator={e(@object, :created, :creator, nil) || e(@activity, :created, :creator, nil) ||
                        e(@activity, :subject, nil)}
                      participants={@participants}
                      quotes={@quotes}
                    />
                  {#else}
                    <StatelessComponent
                      module={component}
                      myself={@myself}
                      __context__={@__context__}
                      showing_within={@showing_within}
                      thread_mode={@thread_mode}
                      activity={maybe_get(component_assigns, :activity, @activity)}
                      object={maybe_get(component_assigns, :object, @object)}
                      object_boundary={maybe_get(component_assigns, :object_boundary, @object_boundary)}
                      object_type={maybe_get(component_assigns, :object_type, @object_type)}
                      object_type_readable={maybe_get(component_assigns, :object_type_readable, @object_type_readable)}
                      verb={maybe_get(component_assigns, :verb, @verb)}
                      thread_id={maybe_get(component_assigns, :thread_id, @thread_id)}
                      thread_title={maybe_get(component_assigns, :thread_title, @thread_title)}
                      permalink={maybe_get(component_assigns, :permalink, @permalink)}
                      viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                      activity_component_id={maybe_get(component_assigns, :activity_component_id, @activity_component_id)}
                      parent_id={@activity_component_id}
                      published_in={maybe_get(component_assigns, :published_in, @published_in)}
                      labelled={maybe_get(component_assigns, :labelled, @labelled)}
                      reply_count={maybe_get(component_assigns, :reply_count, @reply_count)}
                      is_remote={maybe_get(component_assigns, :is_remote, @is_remote)}
                      hide_actions={@hide_actions}
                      subject_user={@subject_user}
                      creator={e(maybe_get(component_assigns, :object, @object), :created, :creator, nil) ||
                        e(maybe_get(component_assigns, :activity, @activity), :created, :creator, nil) ||
                        e(maybe_get(component_assigns, :activity, @activity), :subject, nil)}
                    />
                  {/if}
                {/if}
              {#match _}
                <StatelessComponent
                  :if={@hide_activity != "dynamic"}
                  module={component}
                  activity_component_id={id(component_assigns)}
                  activity_prepared={:defer_to_render}
                  activity_inception={maybe_get(component_assigns, :activity_inception, @activity_inception)}
                  myself={nil}
                  created_verb_display={@created_verb_display}
                  showing_within={maybe_get(component_assigns, :showing_within, @showing_within)}
                  thread_mode={@thread_mode}
                  activity={maybe_get(component_assigns, :activity, @activity)}
                  object={maybe_get(component_assigns, :object, @object)}
                  object_id={maybe_get(component_assigns, :object_id, @object_id)}
                  object_boundary={maybe_get(component_assigns, :object_boundary, @object_boundary)}
                  object_type={maybe_get(component_assigns, :object_type, @object_type)}
                  object_type_readable={maybe_get(component_assigns, :object_type_readable, @object_type_readable)}
                  date_ago={maybe_get(component_assigns, :date_ago, @date_ago)}
                  verb={maybe_get(component_assigns, :verb, @verb)}
                  verb_display={maybe_get(component_assigns, :verb_display, @verb_display)}
                  permalink={maybe_get(component_assigns, :permalink, @permalink)}
                  thread_url={maybe_get(component_assigns, :thread_url, @thread_url)}
                  thread_id={maybe_get(component_assigns, :thread_id, @thread_id)}
                  thread_level={maybe_get(component_assigns, :thread_level, @thread_level)}
                  viewing_main_object={maybe_get(component_assigns, :viewing_main_object, @viewing_main_object)}
                  show_minimal_subject_and_note={maybe_get(component_assigns, :show_minimal_subject_and_note, @show_minimal_subject_and_note)}
                  hide_reply={maybe_get(component_assigns, :hide_reply, @hide_reply)}
                  profile={maybe_get(component_assigns, :profile, nil)}
                  character={maybe_get(component_assigns, :character, nil)}
                  media={maybe_get(component_assigns, :media, nil)}
                  json={maybe_get(component_assigns, :json, nil)}
                  label={maybe_get(component_assigns, :label, nil)}
                  class={maybe_get(component_assigns, :class, nil)}
                  to={maybe_get(component_assigns, :to, nil)}
                  is_remote={maybe_get(component_assigns, :is_remote, @is_remote)}
                  hide_actions={maybe_get(component_assigns, :hide_actions, @hide_actions)}
                />
            {/case}
          {/for}
        {/if}
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
        activity_inception,
        subject_user
      )

  # don't show subject twice
  def component_activity_subject(verb, activity, _, Bonfire.Data.Identity.User, _, _, _),
    do: [
      {Bonfire.UI.Social.Activity.SubjectMinimalLive,
       %{
         verb: verb,
         subject_id: e(activity, :subject_id, nil),
         subjects_more: e(activity, :subjects_more, []),
         profile: e(activity, :subject, :profile, nil),
         character: e(activity, :subject, :character, nil)
       }}
    ]

  # quoting a reply_to <-- this is handled by the Bonfire.UI.Social.Activity.SubjectLive internally
  # def component_activity_subject(_, _, %{activity_inception: true}), do: [Bonfire.UI.Social.Activity.SubjectRepliedLive]

  # def component_activity_subject(verb, activity, _, object_type, _, _, _)
  #     when verb in @react_or_simple_verbs and object_type == Bonfire.Data.Identity.User do
  #   [
  #     {Bonfire.UI.Social.Activity.SubjectMinimalLive,
  #      %{
  #        verb: verb,
  #        subject_id: e(activity, :subject_id, nil),
  #        subjects_more: e(activity, :subjects_more, []),
  #        profile: e(activity, :subject, :profile, nil),
  #        character: e(activity, :subject, :character, nil)
  #      }}
  #   ]
  # end

  # def component_activity_subject(verb, activity, _object, _object_type, :notifications, _, _)
  #     when verb in @react_or_request_verbs,
  #     do: [
  #       {Bonfire.UI.Social.Activity.SubjectMinimalLive,
  #        %{
  #          # activity: repo().maybe_preload(activity, subject: [:character]),
  #          verb: verb,
  #          subject_id: e(activity, :subject_id, nil),
  #          subjects_more: e(activity, :subjects_more, []),
  #          profile: e(activity, :subject, :profile, nil),
  #          character: e(activity, :subject, :character, nil)
  #        }}
  #     ]

  # reactions should show the reactor (or requester for requests) + original creator

  def component_activity_subject(
        "Request to Quote" = verb,
        activity,
        object,
        object_type,
        _,
        activity_inception,
        _
      ) do
    # activity: repo().maybe_preload(activity, subject: [:character]),
    quote_post = e(activity, :edge, :subject, nil)
    id = "nested_quote_post_#{activity_inception}_#{id(quote_post)}"

    ([
       {Bonfire.UI.Social.Activity.SubjectMinimalLive,
        %{
          verb: verb,
          subject_id: e(activity, :subject_id, nil),
          subjects_more: e(activity, :subjects_more, []),
          profile: e(activity, :subject, :profile, nil),
          character: e(activity, :subject, :character, nil)
        }},
       {Bonfire.UI.Social.ActivityLive,
        %{
          id: id,
          activity: %{subject: e(activity, :subject, nil)},
          object: quote_post,
          activity_inception: id,
          showing_within: :quote_post,
          viewing_main_object: false,
          hide_actions: true,
          class: "quote-preview"
        }
        |> prepare_assigns()}
     ] ++ component_activity_maybe_creator(activity, object, object_type))
    |> debug("MATCHED react case for verb: #{verb} in component_activity_subject")
  end

  def component_activity_subject(verb, activity, object, object_type, _, _, _)
      when verb in @react_or_simple_verbs do
    # activity: repo().maybe_preload(activity, subject: [:character]),
    ([
       {Bonfire.UI.Social.Activity.SubjectMinimalLive,
        %{
          verb: verb,
          subject_id: e(activity, :subject_id, nil),
          subjects_more: e(activity, :subjects_more, []),
          profile: e(activity, :subject, :profile, nil),
          character: e(activity, :subject, :character, nil)
        }}
     ] ++ component_activity_maybe_creator(activity, object, object_type))
    |> debug("MATCHED react case for verb: #{verb} in component_activity_subject")
  end

  # create (or reply) activities
  def component_activity_subject(
        verb,
        %{subject: %{profile: %{id: _} = profile, character: %{id: _} = character}},
        _,
        _,
        _,
        _,
        _
      )
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]

  # replies (when shown in notifications)
  def component_activity_subject(verb, _activity, _, _, :notifications, _, _)
      when verb in @reply_verbs,
      do: []

  def component_activity_subject(verb, %{subject: %{profile: %{id: _} = profile}}, _, _, _, _, _)
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: nil}}]

  def component_activity_subject(
        verb,
        %{subject: %{character: %{id: _} = character}},
        _,
        _,
        _,
        _,
        _
      )
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: nil, character: character}}]

  def component_activity_subject(verb, %{subject_id: id}, _, _, _, _, %{
        id: id,
        profile: profile,
        character: character
      })
      when verb in @create_or_reply_verbs,
      do: [{Bonfire.UI.Social.Activity.SubjectLive, %{profile: profile, character: character}}]

  # def component_activity_subject(verb, %{subject_id: id} = _activity, %{created: %{creator: nil}} = _object, _object_type, _, _, _) when verb in @create_or_reply_verbs, do: [{Bonfire.UI.Social.Activity.SubjectLive, %{subject_id: id}}]

  # def component_activity_subject(verb, %{subject_id: id} = activity, object, object_type, _, _, _)
  # when verb in @create_or_reply_verbs,
  # do: if is_nil(e(activity, :object, :created, :creator, nil)) and is_nil(e(object, :created, :creator, nil)), do: [{Bonfire.UI.Social.Activity.SubjectLive, %{subject_id: id}}], else: component_activity_maybe_creator(activity, object, object_type)

  # Handle smart_input showing_within - extract subject info from any activity structure
  def component_activity_subject(verb, activity, object, object_type, :smart_input, _, _) do
    # Try to extract subject info from various possible structures
    subject_id = e(activity, :subject_id, nil) || e(activity, :subject, :id, nil)

    if subject_id do
      # Check if we have preloaded subject data
      profile = e(activity, :subject, :profile, nil)
      character = e(activity, :subject, :character, nil)

      # If we have subject_id but no profile/character, try to get creator data instead
      if is_nil(profile) and is_nil(character) do
        activity
        |> component_activity_maybe_creator(object, object_type)
      else
        # We have proper subject data
        [
          {Bonfire.UI.Social.Activity.SubjectLive,
           %{
             verb: verb,
             subject_id: subject_id,
             profile: profile,
             character: character
           }}
        ]
      end
    else
      # Fall back to the default behavior when no subject is found
      activity
      |> component_activity_maybe_creator(object, object_type)
    end
  end

  # other
  def component_activity_subject(_verb, activity, object, object_type, _, _, _),
    do:
      activity
      # |> debug("activity")
      |> component_activity_maybe_creator(object, object_type)

  # @decorate time()
  def component_activity_maybe_creator(activity, object, object_type)

  def component_activity_maybe_creator(_, _, object_type)
      when object_type == Bonfire.Data.Identity.User,
      do: []

  #  if subject is also the creator use that
  def component_activity_maybe_creator(
        %{subject: %{id: id} = subject} = _activity,
        %{created: %{creator_id: id}} = _object,
        _
      ),
      do: component_maybe_creator(subject) || []

  def component_activity_maybe_creator(
        #  NOTE: this is when creator_id==subject_id
        %{subject: %{id: id} = subject, object: %{created: %{creator_id: id}}} = activity,
        object,
        _
      ),
      do:
        component_maybe_creator(subject) ||
          component_maybe_creator_fallback(activity, object)

  # def component_activity_maybe_creator(
  #       %{object: %{created: %{creator_id: id, creator: nil}}} = _activity,
  #       _object,
  #       _
  #     ),
  #     do: warn("zzzz") && [{Bonfire.UI.Social.Activity.SubjectLive, %{subject_id: id}}]

  #   def component_activity_maybe_creator(
  #       _activity,
  #       %{created: %{creator_id: id, creator: nil}} = _object,
  #       _
  #     ),
  #     do: [{Bonfire.UI.Social.Activity.SubjectLive, %{subject_id: id}}]

  def component_activity_maybe_creator(
        activity,
        %{created: %{creator: %{} = creator}} = object,
        _
      ),
      do:
        component_maybe_creator(creator) |> debug("component_activity_maybe_creator: result1") ||
          component_maybe_creator_fallback(activity, object)
          |> debug("component_activity_maybe_creator: fallback result1")

  def component_activity_maybe_creator(
        %{object: %{created: %{creator: %{} = creator}}} = activity,
        object,
        _
      ),
      do:
        component_maybe_creator(creator) |> debug("component_activity_maybe_creator: result2") ||
          component_maybe_creator_fallback(activity, object)
          |> debug("component_activity_maybe_creator: fallback result2")

  def component_activity_maybe_creator(activity, object, _) do
    # debug(activity, "component_activity_maybe_creator: activity")
    # debug(object, "component_activity_maybe_creator: object")
    component_maybe_creator_fallback(activity, object)
    # |> debug("component_activity_maybe_creator: fallback result3")
  end

  def component_maybe_creator(%{
        creator_profile: %{id: id} = profile,
        creator_character: %{id: _} = character
      }),
      do: [
        {Bonfire.UI.Social.Activity.SubjectLive,
         %{verb: "Create", subject_id: id, profile: profile, character: character}}
      ]

  # def component_maybe_creator(%{provider: %{id: _} = provider} = object),
  #   do: [{Bonfire.UI.ValueFlows.Preview.ProviderReceiverLive, %{object: object}}]

  # def component_maybe_creator(%{primary_accountable: %{id: _} = primary_accountable} = object),
  #   do: [{Bonfire.UI.ValueFlows.Preview.ProviderReceiverLive, %{object: object}}]

  # def component_maybe_creator(%{receiver: %{id: _} = receiver} = object),
  #   do: [{Bonfire.UI.ValueFlows.Preview.ProviderReceiverLive, %{object: object}}]

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

  def component_maybe_creator(%{created: %{creator: %{} = creator}} = object) do
    debug("component_maybe_creator: found created.creator")
    debug(creator, "creator details")

    creator
    |> component_maybe_creator()
  end

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
          profile: %{id: id} = profile,
          character: %{id: _} = character
        } = _creator
      ),
      do: [
        {Bonfire.UI.Social.Activity.SubjectLive,
         %{verb: "Create", subject_id: id, profile: profile, character: character}}
      ]

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

  def component_maybe_creator(_activity_or_object) do
    # warn(activity_or_object, "could not find a creator")
    nil
  end

  defp component_maybe_creator_fallback(activity, object),
    do:
      component_maybe_creator(object) ||
        component_maybe_creator(activity) ||
        (
          creator =
            e(object, :created, :creator, nil) || e(activity, :created, :creator, nil) ||
              e(activity, :object, :created, :creator, nil) || e(object, :creator, nil) ||
              e(activity, :object, :creator, nil)

          creator_id =
            e(object, :created, :creator_id, nil) || e(activity, :created, :creator_id, nil) ||
              e(object, :creator_id, nil) || e(activity, :object, :creator_id, nil)

          case (creator ||
                  if(not is_nil(creator_id) and creator_id == e(activity, :subject_id, nil),
                    do: e(activity, :subject, nil)
                  ) || creator_id)
               |> debug("this is a fallback, component_maybe_creator *should* handle most cases") do
            nil ->
              debug("could not find a creator in activity or object")
              debug(activity, "activity")
              debug(object, "object")
              [Bonfire.UI.Social.Activity.NoSubjectLive]

            # [Bonfire.UI.Social.Activity.SubjectLive]

            %{
              profile: %{id: id} = profile,
              character: %{id: _} = character
            } ->
              [
                {Bonfire.UI.Social.Activity.SubjectLive,
                 %{verb: "Create", subject_id: id, profile: profile, character: character}}
              ]

            creator_id when is_binary(creator_id) ->
              debug("could only find a creator_id")
              # debug(activity)
              # debug(object)
              [
                {Bonfire.UI.Social.Activity.SubjectLive,
                 %{verb: "Create", subject_id: creator_id}}
              ]

            other ->
              error(other, "invalid creator")

              # [Bonfire.UI.Social.Activity.NoSubjectLive]
              [{Bonfire.UI.Social.Activity.SubjectLive, %{verb: "Create"}}]
          end
        )

  def prepare_reply_to(%{
        id: activity_id,
        reply_to:
          %{
            post_content: %{id: _id} = reply_to_post_content,
            created: %{
              creator: %{
                character: %{id: creator_id} = _subject_character,
                profile: %{id: _} = _subject_profile
              }
            }
          } = reply_to
      }) do
    debug("we have a reply_to, preloaded with post_content")

    %{
      activity_id: activity_id,
      object: reply_to_post_content,
      # object_type: Bonfire.Data.Social.Post,
      subject_id: creator_id,
      activity: reply_to
    }
  end

  def prepare_reply_to(%{
        id: activity_id,
        reply_to:
          %{
            id: reply_to_id,
            created: %{
              creator: %{
                character: %{id: _} = subject_character,
                profile: %{id: creator_id} = subject_profile
              }
            }
          } = reply_to
      })
      when is_binary(reply_to_id) do
    debug("we have another kind of reply_to, preloaded with creator")

    %{
      activity_id: activity_id,
      object: reply_to,
      # object_type: Types.object_type(reply_to),
      subject_id: creator_id,
      activity: %{
        # Activities.load_object(reply_to, skip_boundary_check: true),
        subject: %{
          profile: subject_profile,
          character: subject_character
        }
      }
    }
  end

  def prepare_reply_to(%{
        id: activity_id,
        reply_to:
          %{
            id: _reply_to_id
          } = reply_to
      }) do
    debug("we have another kind of reply_to, but no creator")

    %{
      activity_id: activity_id,
      object: reply_to,
      # object_type: Types.object_type(reply_to),
      subject_id: true,
      activity: %{
        # Activities.load_object(reply_to, skip_boundary_check: true),
        subject: nil
      }
    }
  end

  # def prepare_reply_to(
  #       %{
  #         id: activity_id,
  #         reply_to:
  #           %{
  #             id: reply_to_id
  #           } = replied
  #       }
  #     )
  #     # other kind of reply
  #     when is_binary(reply_to_id) do
  #   maybe_load_in_reply_to(replied, activity_id, current_user: current_user(assigns))
  # end

  # def prepare_reply_to(
  #       %{id: object_id, thread: %{id: thread_id} = thread}
  #     )
  #     when object_id != thread_id,
  #     do: maybe_load_in_reply_to(thread, thread_id, current_user: current_user(assigns))

  def prepare_reply_to(%{replied: %{id: _} = replied}),
    do: prepare_reply_to(replied)

  def prepare_reply_to(_),
    do: nil

  # @decorate time()
  def component_maybe_in_reply_to(
        reply_to,
        showing_within,
        activity_inception,
        viewing_main_object,
        thread_mode,
        thread_id,
        thread_title,
        activity_component_id
      )

  def component_maybe_in_reply_to(
        reply_to,
        showing_within,
        activity_inception,
        viewing_main_object,
        thread_mode,
        _thread_id,
        _thread_title,
        _activity_component_id
      )
      # cases where we do not show reply_to
      when is_nil(reply_to) or
             (not is_nil(activity_inception) or
                (viewing_main_object != true and showing_within in [:thread, :smart_input] and
                   thread_mode != :flat)),
      do: []

  def component_maybe_in_reply_to(
        %{object: %{id: reply_to_id}},
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
        %{
          activity_id: activity_id,
          subject_id: subject_id,
          activity: activity,
          object: %{id: object_id} = reply_to_object
        } = _reply_to,
        _,
        _,
        _,
        _,
        _thread_id,
        thread_title,
        activity_component_id
      ) do
    debug(reply_to_object, "we have a reply_to, preloaded with post_content?")

    Bonfire.Common.Cache.put("has_reply_to:#{activity_id}", true)

    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "reply_to-#{activity_component_id}-#{object_id}",
         activity_inception: activity_id,
         #  show_minimal_subject_and_note: name_or_text(reply_to_object) || true,
         # FIXME: not showing reply_to post content
         show_minimal_subject_and_note: true,
         viewing_main_object: false,
         thread_title: thread_title,
         object: reply_to_object,
         object_type: Types.object_type(reply_to_object),
         subject_id: subject_id,
         activity: activity,
         cw: sensitive?(activity)
         #  || e(reply_to_object, :summary, nil) != nil <-- summary is not a replacement for cw
       }
       |> prepare_assigns()}
    ]
  end

  # def component_maybe_in_reply_to(
  #       %{activity_id: activity_id, object: %Ecto.Association.NotLoaded{}},
  #       showing_within,
  #       _,
  #       viewing_main_object,
  #       thread_mode,
  #       _,
  #       _,
  #       _
  #     )
  #     when viewing_main_object != true and (showing_within != :thread or thread_mode == :flat) do
  #   case Bonfire.Common.Cache.get("has_reply_to:#{activity_id}") do
  #     {:ok, true} ->
  #       debug("reply_to was not loaded")

  #       [
  #         {:html,
  #          """
  #          <div role="status" class="space-y-2.5 animate-pulse max-w-[50%] mb-2">
  #          <div class="flex items-center w-full space-x-2">
  #          <div class="h-2.5 bg-base-content/10 rounded-full w-10"></div>
  #          <div class="h-2.5 bg-base-content/10 rounded-full w-24"></div>
  #          <div class="h-2.5 bg-base-content/10 rounded-full w-full"></div>
  #          </div>
  #          <span class="sr-only">Loading...</span>
  #          </div>

  #          """}
  #       ]

  #     _ ->
  #       debug(id, "no has_reply_to in cache")
  #       []
  #   end
  # end

  def component_maybe_in_reply_to(a, _, _, _, _, _, _, _) do
    debug(a, "cannot determine if there's a reply_to")
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

  #      %{
  #        object: e(reply_to_activity, :object, nil),
  #        # |> IO.inspect,
  #        activity: reply_to_activity |> Map.delete(:object),
  #      }
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
  def component_object(object, object_type, assigns \\ %{})

  # def component_object(%{profile: %{id: _}}, object_type, _)
  #     when object_type not in [:group, :topic],
  #     do: [Bonfire.UI.Me.Preview.CharacterLive]
  # def component_object(%{character: %{id: _}}, object_type, _)
  #     when object_type not in [:group, :topic],
  #     do: [Bonfire.UI.Me.Preview.CharacterLive]
  # def component_object(_, Bonfire.Data.Identity.User, _),
  #   do: [Bonfire.UI.Me.Preview.CharacterLive]

  def component_object(object, type, assigns) when is_atom(type) and not is_nil(type) do
    component_for_object_type(type, object, assigns)
  end

  def component_object(%{} = object, object_type, assigns) do
    case object_type || Types.object_type(object) do
      type when is_atom(type) and not is_nil(type) ->
        debug(type, "component object_type recognised")
        component_for_object_type(type, object, assigns)

      _ ->
        warn(
          object_type || object,
          "use UnknownLive because component object_type NOT detected"
        )

        [Bonfire.UI.Social.Activity.UnknownLive]
    end
  end

  def component_object(_, _, _) do
    debug("activity has no object")
    []
  end

  def component_for_object_type(:article, _, assigns) do
    [{Bonfire.UI.Social.Activity.ArticleLive, assigns}]
  end

  def component_for_object_type(
        Bonfire.Data.Social.Post,
        %{post_content: %{html_body: _}},
        assigns
      ),
      do: [{Bonfire.UI.Social.Activity.NoteLive, assigns}]

  def component_for_object_type(Bonfire.Data.Social.Post, %{html_body: _}, assigns),
    do: [{Bonfire.UI.Social.Activity.NoteLive, assigns}]

  def component_for_object_type(Bonfire.Data.Social.PostContent, _, assigns),
    do: [{Bonfire.UI.Social.Activity.NoteLive, assigns}]

  def component_for_object_type(Bonfire.Data.Social.Post, _object, _) do
    debug("post with no text content (eg. only with attachments)")
    []
  end

  def component_for_object_type(Bonfire.Data.Social.Message, _, assigns),
    do: [{Bonfire.UI.Social.Activity.NoteLive, assigns}]

  # def component_for_object_type(type, _) when type in [Bonfire.Data.Identity.User],
  #   do: [Bonfire.UI.Me.Preview.CharacterLive]
  # def component_for_object_type(type, _) when type in [Bonfire.Data.Social.Follow],
  #   do: [Bonfire.UI.Me.Preview.CharacterLive]

  # def component_for_object_type(type, _) when type in [:group],
  #   do: [Bonfire.UI.Groups.Preview.GroupLive]

  # def component_for_object_type(type, _) when type in [:topic, Bonfire.Classify.Category],
  #   do: [Bonfire.Classify.Web.Preview.CategoryLive]

  # def component_for_object_type(type, object) when type in [ValueFlows.EconomicEvent],
  #   do: [Bonfire.UI.ValueFlows.Preview.EconomicEventLive.activity_component(object)]

  # def component_for_object_type(type, _) when type in [ValueFlows.EconomicResource],
  #   do: [Bonfire.UI.ValueFlows.Preview.EconomicResourceLive]

  # # TODO: choose between Task and other Intent types
  # def component_for_object_type(type, _) when type in [ValueFlows.Planning.Intent],
  #   do: [Bonfire.UI.ValueFlows.Preview.IntentTaskLive]

  def component_for_object_type(Bonfire.Data.Social.APActivity, object, assigns) do
    json =
      e(object, :json, nil)
      |> debug("APActivity json")

    types =
      List.wrap(e(json, "object", "type", nil) || e(json, "type", nil) || "Remote Activity")
      |> Enum.map(&String.capitalize/1)

    # Check for matching types in order of preference
    {type, component} =
      cond do
        Enum.any?(types, &(&1 == "Event")) ->
          {l("Event"), Bonfire.UI.Social.Activity.EventActivityStreamsLive}

        Enum.any?(types, &(&1 == "Arrive")) ->
          {l("Arrive"), Bonfire.UI.Social.Activity.ArriveActivityStreamsLive}

        # NOTE: probably not used now as they're being created as Media
        Enum.any?(types, &(&1 == "Video")) ->
          {l("Video"), Bonfire.UI.Social.Activity.VideoActivityStreamsLive}

        Enum.any?(types, &(&1 == "Edition" || &1 == "Book")) ->
          {l("Edition"), Bonfire.UI.Social.Activity.BookActivityStreamsLive}

        # NOTE: probably not used now as Article is being created as a Post and Page as Media
        Enum.any?(types, &(&1 == "Article" || &1 == "Page")) ->
          {l("Article"), Bonfire.UI.Social.Activity.ArticleActivityStreamsLive}

        # NOTE: probably not used now as they're being created as Media
        Enum.any?(types, &(&1 == "Audio" || &1 == "PodcastEpisode")) ->
          {l("Audio"), Bonfire.UI.Social.Activity.AudioActivityStreamsLive}

        true ->
          {List.first(types) || l("Remote Activity"),
           Bonfire.UI.Social.Activity.UnknownActivityStreamsLive}
      end

    [
      {component, Enum.into(%{json: json, object_type_readable: type}, assigns)}
    ] ++ nested_object_components(json)
  end

  # def component_for_object_type(type, object) when type in [ValueFlows.Process], do: [Bonfire.UI.ValueFlows.Preview.ProcessListLive.activity_component(object)]

  def component_for_object_type(type, object, _assigns) when is_atom(type) and not is_nil(type) do
    component_def_for(:object_preview, type, object, &component_object_fallback/2)
  end

  def component_for_object_type(type, object, _assigns) do
    component_object_fallback(type, object)
  end

  defp component_def_for(key, type, object, fallback) when is_atom(type) and not is_nil(type) do
    case Config.get([:ui, key, type]) do
      nil ->
        if is_function(fallback), do: fallback.(type, object), else: [fallback]

      module when is_atom(module) ->
        [module]

      module_def when is_list(module_def) ->
        module_def

      module_def when is_tuple(module_def) ->
        [module_def]

      module_fun when is_function(module_fun) ->
        module_fun.(object)

      other ->
        error(other, "Unrecognised object_preview config")
        if is_function(fallback), do: fallback.(type, object), else: [fallback]
    end
    |> debug("component from config")
  end

  defp component_object_fallback(_object_type, %{profile: %{id: _}}),
    do: [Bonfire.UI.Me.Preview.CharacterLive]

  defp component_object_fallback(_object_type, %{character: %{id: _}}),
    do: [Bonfire.UI.Me.Preview.CharacterLive]

  defp component_object_fallback(type, %{} = object) when type == Bonfire.Files.Media,
    do: [{Bonfire.UI.Social.Activity.MediaLive, %{media: object}}]

  defp component_object_fallback(type, %{named: %{name: name}} = object)
       when type == Bonfire.Tag.Hashtag do
    [{LinkLive, label: "##{name}", to: path(object, [], preload_if_needed: false)}]
  end

  defp component_object_fallback(_type, %{name: name} = object) do
    [{LinkLive, label: name, to: path(object, [], preload_if_needed: false)}]
  end

  defp component_object_fallback(_type, %{named: %{name: name}} = object) do
    [{LinkLive, label: name, to: path(object, [], preload_if_needed: false)}]
  end

  defp component_object_fallback(type, _object) do
    warn(type, "no component set up for object_type, fallback to UnknownLive")

    [Bonfire.UI.Social.Activity.UnknownLive]
  end

  defp primary_image_and_component_maybe_attachments(
         object_type,
         activity,
         object,
         _activity_inception
       ) do
    do_primary_image_and_component_maybe_attachments(
      id(object) || id(activity),
      e(activity, :files, nil) || e(object, :files, nil) || e(activity, :media, nil) ||
        e(object, :media, nil),
      object_type
    )

    # |> debug("prim_img")
  end

  # defp primary_image_and_component_maybe_attachments(_, _activity, _object, _activity_inception), do: []

  def do_primary_image_and_component_maybe_attachments(_id, files, object_type)
      when (is_list(files) and files != []) or is_map(files) do
    {primary_image, files} =
      if object_type == :article, do: Bonfire.Files.split_primary_image(files), else: {nil, files}

    {primary_image,
     [
       {Bonfire.UI.Social.Activity.MediaLive, %{media: files}}
     ]}
  end

  def do_primary_image_and_component_maybe_attachments(id, other, _object_type) do
    # use cached amounts of images to display from MediaLive in case media is preloaded async
    case Bonfire.Common.Cache.get("num_media:#{id}") do
      {:ok, [multimedia_count, image_count, gif_count, link_count]} ->
        {nil,
         [
           {Bonfire.UI.Social.Activity.MediaSkeletonLive,
            %{
              multimedia_count: multimedia_count,
              image_count: image_count,
              gif_count: gif_count,
              link_count: link_count
            }}
         ]}

      _ ->
        debug(other, "no files")
        {nil, []}
    end
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
  def component_actions(_, _, _, showing_within, activity_inception, _)
      when not is_nil(activity_inception) and showing_within != :thread,
      do: []

  def component_actions(_, _, _, showing_within, _, _)
      when showing_within == :smart_input,
      do: []

  # WIP: THIS NEEDS TO BE REFACTORED ACCORDING TO actions_for_object_type
  def component_actions("Flag", _, _, _, _, _), do: [Bonfire.UI.Social.Activity.ActionsLive]

  # def component_actions(_, activity, _, _, _, true) do
  #   [Bonfire.UI.Social.Activity.MainObjectInfoLive] ++ component_actions(nil, activity, nil)
  # end

  def component_actions(_, activity, object_type, _, _, _) when not is_nil(object_type) do
    actions_for_object_type(activity, object_type)
  end

  def component_actions(_, _, _, _, _, _), do: []

  # WIP: Customize actions for each activity type
  def actions_for_object_type(_activity, type)
      when type in [Bonfire.Data.Identity.User, Bonfire.Data.Identity.Character],
      do: []

  def actions_for_object_type(_activity, type) when type == Bonfire.Data.Social.Flag, do: []

  def actions_for_object_type(_activity, type)
      when type in [Bonfire.Data.Social.Post, Bonfire.Data.Social.PostContent],
      do: [Bonfire.UI.Social.Activity.ActionsLive]

  # def actions_for_object_type(activity, type)
  #     when type in [Bonfire.Classify.Category],
  #     do: [Bonfire.Classify.Web.CategoryActionsLive]

  # def actions_for_object_type(_activity, type)
  #     when type in [Bonfire.Classify.Category],
  #     do: []

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicEvent],
  #   do: [
  #   {Bonfire.UI.ValueFlows.Preview.EventActionsLive,
  #    %{object: e(activity, :object, :resource_inventoried_as, nil) || e(activity, :object, nil)}}
  # ]

  # def actions_for_object_type(activity, type) when type in [ValueFlows.EconomicResource],
  #   do: [Bonfire.UI.ValueFlows.Preview.ProcessActionsLive]

  # def actions_for_object_type(_activity, type) when type in [ValueFlows.Planning.Intent],
  #   do: []

  # def actions_for_object_type(_activity, type) when type in [ValueFlows.Process],
  #   do: []

  def actions_for_object_type(activity, type) when is_atom(type) and not is_nil(type) do
    component_def_for(:object_actions, type, activity, Bonfire.UI.Social.Activity.ActionsLive)
  end

  def actions_for_object_type(_activity, type) do
    debug(type, "No specific actions defined fot this type")
    [Bonfire.UI.Social.Activity.ActionsLive]
    # [Bonfire.UI.Social.Activity.NoActionsLive]
  end

  # def reply_to_display(%Needle.Pointer{} = reply_to) do
  #   Bonfire.Common.Needles.get!(reply_to)
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

  def component_id(id, fallback, activity_inception \\ nil)

  def component_id(id, _fallback, activity_inception) when is_binary(id) do
    # This is already deterministic, but ensure consistent format
    "#{activity_inception}activity_#{id}"
  end

  def component_id(_id, fallback, activity_inception) do
    # Ensure the fallback is also deterministic
    fallback_id = if is_binary(fallback), do: fallback, else: "fallback"
    "#{activity_inception}#{fallback_id}"
  end

  # This gets compiled in, but you can make the character threshold bigger at runtime
  @default_char_threshold Bonfire.Social.Activities.article_char_threshold()
  # Use a conservative multiplier - ASCII is 1 byte per char, so this should ensure we don't filter out posts that might reach the character threshold
  @min_body_bytes div(@default_char_threshold * 2, 3)

  def is_article?(Bonfire.Data.Social.Post, %{name: name, html_body: html_body})
      when is_binary(name) and is_binary(html_body) and
             byte_size(name) > 2 and byte_size(html_body) > @min_body_bytes do
    String.length(html_body) >
      (Bonfire.Social.Activities.article_char_threshold() ||
         @default_char_threshold)
  end

  def is_article?(Bonfire.Data.Social.Post, %{
        post_content: %{name: name, html_body: html_body}
      }),
      do: is_article?(Bonfire.Data.Social.Post, %{name: name, html_body: html_body})

  def is_article?(_, _), do: false

  @doc """
  Returns a list of components for rendering nested object previews in APActivity JSON.
  Uses the stored metadata to determine which fields have preloaded pointers.
  Reuses existing component_object/3 logic to keep it DRY.
  """
  def nested_object_components(json) when is_map(json) do
    preloaded_fields = Map.get(json, "__bonfire_preloaded_fields__", [])

    if preloaded_fields != [] do
      Enum.flat_map(preloaded_fields, fn path ->
        field_str = Enum.join(path, ".")

        # path is now a list of keys for nested fields
        case get_in(json, path) do
          %{"nested_object" => pointer_object} = _field_data when is_map(pointer_object) ->
            nested_object_preview_components(
              field_str,
              Types.object_type(pointer_object),
              pointer_object
            )

          list when is_list(list) ->
            list
            |> Enum.with_index()
            |> Enum.flat_map(fn {item, index} ->
              case item do
                %{"nested_object" => pointer_object} = _item_data when is_map(pointer_object) ->
                  nested_object_preview_components(
                    "#{field_str}[#{index}]",
                    Types.object_type(pointer_object),
                    pointer_object
                  )

                _ ->
                  []
              end
            end)

          _ ->
            []
        end
      end)
    else
      []
    end
  end

  def nested_object_components(_), do: []

  defp nested_object_preview_components(field_str, Bonfire.Data.Social.Activity, pointer_activity) do
    [
      {Bonfire.UI.Social.ActivityLive,
       %{
         id: "nested_object_#{field_str}_#{id(pointer_activity)}",
         activity: pointer_activity,
         object: nil,
         activity_inception: "nested_#{field_str}",
         showing_within: :nested_preview,
         viewing_main_object: false,
         hide_actions: true,
         class: ""
       }
       |> prepare_assigns()}
    ]
  end

  defp nested_object_preview_components(field_name, object_type, pointer_object) do
    # Reuse the existing component_object logic but wrap it in a preview container
    object_components = component_object(pointer_object, object_type, %{})

    # Wrap each component with preview styling and add a header
    preview_header = [
      {:html, "<h4 class=\"text-sm font-medium text-base-content/70 mb-2\">#{field_name}:</h4>"}
    ]

    preview_components =
      Enum.map(object_components, fn
        {component_module, component_assigns} when is_map(component_assigns) ->
          {component_module,
           Map.merge(
             %{
               object: pointer_object,
               class: "",
               showing_within: :nested_preview,
               hide_actions: true
             },
             component_assigns
           )}

        {component_module, component_assigns} ->
          {component_module, component_assigns}

        component_module when is_atom(component_module) ->
          {component_module,
           %{
             object: pointer_object,
             class: "",
             showing_within: :nested_preview,
             hide_actions: true
           }}
      end)

    # preview_header ++ preview_components WIP temp removed to find a better way to show preview_header
    preview_components
  end

  @doc """
  Check if the object has quoted posts and return components to render them
  """
  def component_maybe_quote_post(activity_component_id, quotes) do
    case quotes do
      [] ->
        []

      quoted_objects when is_list(quoted_objects) ->
        quoted_objects
        |> Enum.with_index()
        |> Enum.map(fn {quoted_object, index} ->
          id = "#{activity_component_id}_quoted_post_#{index}_#{id(quoted_object)}"

          {Bonfire.UI.Social.ActivityLive,
           %{
             id: id,
             activity: quoted_object |> debug("quoted_object"),
             object: quoted_object,
             activity_inception: id,
             showing_within: :quote_preview,
             viewing_main_object: false,
             hide_actions: true,
             thread_url: nil,
             thread_id: id(quoted_object),
             class: "quote-preview"
           }
           |> prepare_assigns()}
        end)
    end
  end
end
