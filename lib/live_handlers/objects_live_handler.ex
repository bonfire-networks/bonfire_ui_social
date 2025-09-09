defmodule Bonfire.Social.Objects.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  alias Bonfire.Social.Objects

  def handle_event("set_name", %{"thread_id" => _id, "name" => name} = params, socket) do
    with {:ok, _} <-
           Objects.set_name(e(params, "thread_id", nil) || e(assigns(socket), :object, nil), name,
             current_user: current_user_required!(socket)
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign(thread_title: name)
       |> assign_flash(:info, l("Name updated!"))}
    end
  end

  def handle_event("reset_boundary", %{"boundary" => boundary} = params, socket) do
    thing =
      params["object_id"] || ed(assigns(socket), params["object_assign"] || :object, nil)

    with {:ok, _} <-
           Objects.reset_preset_boundary(
             current_user_required!(socket),
             thing,
             e(assigns(socket), :boundary_preset, nil) ||
               e(params, "previous_boundary_preset", nil),
             to_boundaries: boundary,
             to_circles: params["to"]
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Boundary updated!"))
       |> maybe_redirect_to(
         e(params, "go", nil),
         fallback: current_url(socket)
       )}
    end
  end

  def handle_event("reset_boundary", %{"id" => acl_id} = params, socket) do
    handle_event("reset_boundary", Map.put(params, "boundary", acl_id), socket)
  end

  def handle_event("share", %{"boundary" => boundary} = params, socket) do
    current_user = current_user(socket)

    thing =
      ed(assigns(socket), params["object_assign"] || :object, nil)
      |> debug()

    creator =
      if not is_nil(thing),
        do:
          e(thing, :creator, nil) || e(thing, :created, :creator, nil) ||
            e(thing, :created, :creator_id, nil) || e(thing, :caretaker, :caretaker, nil) ||
            e(thing, :caretaker, :caretaker_id, nil) || e(thing, :provider, nil)

    cond do
      is_nil(creator) ->
        error("Oops, the system could not find what you are trying to share")

      is_nil(creator) ->
        error(
          "Could not share because the system did not know if you are the creator or caretaker"
        )

      id(creator) != id(current_user) ->
        error(creator, "Not allowed")

      is_struct(thing) ->
        # TODO: check permission
        with {:ok, _} <-
               Objects.publish(current_user, :boost, thing,
                 to_boundaries: boundary,
                 to_circles: params["to"]
               ) do
          {:noreply,
           socket
           |> assign_flash(:info, l("Shared!"))
           |> maybe_redirect_to(
             e(params, "go", nil),
             fallback: current_url(socket)
           )}
        end

      true ->
        error("No object to share")
    end
  end

  def handle_event("share", %{"id" => acl_id} = params, socket) do
    handle_event("share", Map.put(params, "boundary", acl_id), socket)
  end

  def handle_event("quote_accept", %{"id" => request_id} = _params, socket) do
    # debug(socket)

    with {:ok, quote_post} <-
           Bonfire.Social.Quotes.accept(request_id,
             current_user: current_user_required!(socket)
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Quote request accepted!"))
       |> redirect_to(path(quote_post), type: :maybe_external)}
    else
      e ->
        error(e, l("There was an error when trying to accept the quote request"))
    end
  end

  def maybe_redirect_to(socket, to, opts) when is_binary(to) and to != "" do
    redirect_to(
      socket,
      to,
      opts
    )
  end

  def maybe_redirect_to(socket, _path, _) do
    socket
  end

  def handle_event("delete", %{"id" => id} = _params, socket) do
    with {:ok, _} <-
           Objects.delete(id,
             current_user: current_user_required!(socket),
             socket_connected: true
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {
        :noreply,
        socket
        |> assign_flash(:info, l("Deleted!"))
        #  |> redirect_to(
        #    e(params, "redirect_after", nil),
        #    fallback: current_url(socket)
        #  )
      }
    end
  end

  defp init_object_assigns(object, socket) do
    current_user = current_user(socket)

    # TODO: less ugly

    {activity, object} = Map.pop(object, :activity)

    activity =
      activity
      |> Map.put(:object, object)
      # |> Bonfire.Social.Activities.activity_preloads(default_preloads(),
      #   current_user: current_user
      # )
      |> Bonfire.Social.Feeds.LiveHandler.preload_activity_and_object_assocs([:object],
        current_user: current_user,
        # TODO: use same logic as feeds preloads?
        preload:
          Bonfire.Social.Feeds.LiveHandler.feed_extra_preloads_list(
            assigns(socket)[:showing_within],
            assigns(socket)[:thread_mode]
          )
      )
      |> debug()

    {object, activity} = Map.pop(activity, :object)

    init_object_activity_assigns(object, activity, socket)
  end

  defp init_object_activity_assigns(object, activity, socket) do
    # current_user = current_user(socket)
    id = id(object)
    canonical_url = path(object)

    # debug(object, "the object")
    # debug(activity, "the activity")
    # following = if current_user && module_enabled?(Bonfire.Social.Graph.Follows, user) && Bonfire.Social.Graph.Follows.following?(current_user, object), do: [object.id]

    # |> debug("object author")
    author =
      (e(activity, :subject, nil) || e(object, :created, :creator, nil) ||
         e(activity, :created, :creator, nil))
      |> repo().maybe_preload(:settings)

    thread_id = e(activity, :replied, :thread_id, id)
    # |> debug("reply_to_id")
    # reply_to_id = e(assigns, :reply_to_id, id)

    # smart_input_prompt = l("Reply to object:")<>" "<>Text.text_only(e(object, :post_content, :name, e(object, :post_content, :summary, e(object, :post_content, :html_body, reply_to_id))))
    # smart_input_prompt = l("Reply")

    # participants =
    #   Bonfire.Social.Threads.list_participants(Map.put(activity, :object, object), thread_id,
    #     current_user: current_user
    #   )

    # to_circles =
    #   if length(participants) > 0,
    #     do: Enum.map(participants, &{e(&1, :character, :username, l("someone")), e(&1, :id, nil)})

    # names = if length(participants)>0, do: Enum.map_join(participants, ", ", &e(&1, :profile, :name, e(&1, :character, :username, l "someone else")))

    # mentions =
    #   if length(participants) > 0,
    #     do:
    #       Enum.map_join(
    #         participants |> Enum.reject(&(e(&1, :character, :id, nil) == uid(current_user))),
    #         " ",
    #         &("@" <> e(&1, :character, :username, ""))
    #       ) <> " "

    # debug(activity)
    thread_title = e(activity, :replied, :thread, :named, :name, nil)

    socket
    |> assign_generic(
      object_id: id,
      object_loaded: true,
      canonical_url: canonical_url,
      activity: activity,
      object: object,
      sidebar_widgets: [
        users: [
          secondary: [
            # {Bonfire.AI.Web.SummaryLive, [text: e(object, :post_content, :html_body, nil)]},
            {Bonfire.Tag.Web.WidgetTagsLive, []}
          ]
        ],
        guests: [
          secondary: nil
        ]
      ],
      # url: url,
      # page_header_aside: [
      #   {
      #     Bonfire.UI.Social.ObjectHeaderAsideLive,
      #     [
      #       participants: [],
      #       thread_id: thread_id,
      #       activity: activity
      #     ]
      #   }
      # ],
      # participants: participants,
      no_index:
        !Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, author)
        |> debug("no_index"),
      # Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], true,
      #   current_user: author
      # ),
      thread_id: thread_id,
      # reply_to_id: object,
      # smart_input_opts: %{text_suggestion: mentions, prompt: smart_input_prompt},
      # to_circles: to_circles || []
      thread_title: thread_title
    )
    |> maybe_seo_assign(object, activity)

    # |> debug
  end

  defp maybe_seo_assign(socket, %{post_content: %{} = post_content} = object, activity) do
    post_content
    |> Map.put(:pointer, object |> Map.drop([:post_content]))
    |> maybe_seo_assign(socket, ..., activity)
  end

  defp maybe_seo_assign(socket, object, activity) do
    if !socket_connected?(socket),
      do: SEO.assign(socket, Map.put(object, :activity, activity)),
      else: socket
  end

  # TODO: put in Social config like the rest 
  def default_preloads(),
    do: [
      # :default,
      :with_creator,
      :with_post_content,
      # :with_reply_to,
      :with_thread_name,
      :with_parent,
      :with_media,
      :maybe_with_labelled,
      :quote_tags,
      :with_object_peered
    ]

  def load_object_assigns(%{assigns: assigns} = socket), do: load_object_assigns(assigns, socket)
  def load_object_assigns(%{} = assigns), do: load_object_assigns(assigns, assigns)

  def load_object_assigns(
        %{object_id: id, object: %{id: pre_loaded}, activity: _} = assigns,
        socket
      )
      when is_binary(id) and id == pre_loaded do
    debug(pre_loaded, "object pre_loaded")
    init_object_activity_assigns(assigns.object, assigns.activity, socket)
  end

  def load_object_assigns(
        %{post_id: id, object: %{id: pre_loaded}, activity: _} = assigns,
        socket
      )
      when is_binary(id) and id == pre_loaded do
    debug(pre_loaded, "post pre_loaded")
    init_object_activity_assigns(assigns.object, assigns.activity, socket)
  end

  def load_object_assigns(%{post_id: id} = assigns, socket) when is_binary(id) do
    current_user = current_user(assigns) || current_user(socket)

    preloads = default_preloads()

    # debug(params, "PARAMS")
    # debug(url, "post url")
    with id when is_binary(id) <- uid(id),
         {:ok, object} <-
           Utils.maybe_apply(
             Bonfire.Posts,
             :read,
             [id, [current_user: current_user, preload: preloads]],
             fallback_fun: fn ->
               Bonfire.Social.Objects.read(id,
                 current_user: current_user,
                 preload: preloads
               )
             end
           ) do
      init_object_assigns(object, socket)
    else
      _e ->
        not_found_fallback(id, e(assigns, :params, nil), socket)
    end
  end

  def load_object_assigns(%{object_id: id} = assigns, socket) when is_binary(id) do
    current_user = current_user(assigns) || current_user(socket)
    # debug(params, "PARAMS")
    with id when is_binary(id) <- uid(id),
         {:ok, object} <-
           Bonfire.Social.Objects.read(id,
             current_user: current_user,
             preload: default_preloads()
           ) do
      init_object_assigns(
        object,
        socket
      )
    else
      _e ->
        not_found_fallback(id, e(assigns, :params, nil), socket)
    end
  end

  def not_found_fallback(id, params, socket) do
    debug(id, "not found")

    current_url =
      current_url(socket)
      |> String.trim("#")
      |> debug("current_url")

    uid = uid(id)

    case uid && Bonfire.Common.URIs.remote_canonical_url(uid) do
      url when is_binary(url) and url != current_url ->
        debug(url, "remote object - redirect to canonical")

        socket
        |> redirect_to(url, type: :maybe_external)

      _ ->
        canonical_path =
          path(id)
          |> debug("canonical_path")

        if canonical_path && current_url && canonical_path != current_url do
          socket
          |> redirect_to(canonical_path)
        else
          case Bonfire.Common.Types.object_type(
                 maybe_to_atom(e(params, "type", nil) |> debug) |> debug || id
               )
               |> debug("object_type") do
            Bonfire.Data.Identity.User ->
              socket
              |> redirect_to("/user/#{id}")

            type when is_binary(type) or (is_atom(type) and not is_nil(type)) ->
              # It should be noted that this leaks the existence of an object, as well as its type, which may be a privacy issue for some threat models

              thing = Bonfire.Common.Types.object_type_display(type) || l("post")

              msg =
                l("Sorry, you can't view this %{thing}",
                  thing: thing
                )

              if current_user_id(socket) do
                {:error, msg}
              else
                socket
                |> assign_error(msg)
                # |> set_go_after()
                # |> redirect_to(path(:login))
                |> redirect_to(
                  "/remote_interaction?type=read&url=#{Bonfire.Common.URIs.canonical_url(id)}&name=#{thing}"
                )
              end

            _ ->
              {:error, :not_found}
          end
        end
    end
  end
end
