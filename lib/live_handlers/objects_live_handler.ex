defmodule Bonfire.Social.Objects.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  alias Bonfire.Social.Objects

  def handle_event("set_name", %{"id" => id, "name" => name} = params, socket) do
    with {:ok, _} <-
           Objects.set_name(e(params, "id") || e(socket.assigns, :object, nil), name,
             current_user: current_user_required(socket)
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign(page_title: name)
       |> assign_flash(:info, l("Name updated!"))}
    end
  end

  def handle_event("tag", %{"tags" => tags} = params, socket) do
    with {:ok, _} <-
           Bonfire.Social.Tags.maybe_tag(
             current_user_required(socket),
             e(params, "id", nil) || e(socket.assigns, :object, nil),
             tags
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, l("Tagged!"))}
    end
  end

  def handle_event("delete", %{"id" => id} = params, socket) do
    with {:ok, _} <- Objects.delete(id, current_user: current_user_required(socket)) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, l("Deleted!"))
       |> redirect_to(
         e(params, "redirect_after", nil),
         fallback: current_url(socket)
       )}
    end
  end

  def init_object_assigns(object, activity, assigns, socket, page_title \\ nil) do
    current_user = current_user(socket)
    id = ulid(object)

    activity =
      Bonfire.Social.Activities.activity_preloads(activity, :all, current_user: current_user)

    # debug(object, "the object")
    # debug(activity, "the activity")
    # following = if current_user && module_enabled?(Bonfire.Social.Follows, user) && Bonfire.Social.Follows.following?(current_user, object), do: [object.id]

    # |> debug("object author")
    author =
      e(activity, :subject, nil) || e(activity, :created, :creator, nil) ||
        e(activity, :object, :created, :creator, nil)

    thread_id = e(activity, :replied, :thread_id, id)
    # |> debug("reply_to_id")
    reply_to_id = e(assigns, :reply_to_id, id)

    # smart_input_prompt = l("Reply to object:")<>" "<>Text.text_only(e(object, :post_content, :name, e(object, :post_content, :summary, e(object, :post_content, :html_body, reply_to_id))))
    smart_input_prompt = l("Reply")

    participants =
      Bonfire.Social.Threads.list_participants(activity, thread_id, current_user: current_user)

    to_circles =
      if length(participants) > 0,
        do: Enum.map(participants, &{e(&1, :character, :username, l("someone")), e(&1, :id, nil)})

    # names = if length(participants)>0, do: Enum.map_join(participants, ", ", &e(&1, :profile, :name, e(&1, :character, :username, l "someone else")))

    mentions =
      if length(participants) > 0,
        do:
          Enum.map_join(
            participants |> Enum.reject(&(e(&1, :character, :id, nil) == ulid(current_user))),
            " ",
            &("@" <> e(&1, :character, :username, ""))
          ) <> " "

    page_title = e(activity, :replied, :thread, :named, :name, page_title)

    socket
    |> assign_generic(
      object_id: id,
      object_loaded: true,
      activity: activity,
      object: object,
      # url: url,
      participants: participants,
      no_index:
        !Bonfire.Me.Settings.get([Bonfire.Me.Users, :discoverable], true, current_user: author),
      thread_id: thread_id,
      reply_to_id: reply_to_id,
      page_title: page_title,
      smart_input_opts: [text: mentions],
      to_circles: to_circles
    )
  end

  def load_object_assigns(%{assigns: assigns} = socket), do: load_object_assigns(assigns, socket)
  def load_object_assigns(%{} = assigns), do: load_object_assigns(assigns, assigns)

  def load_object_assigns(
        %{object_id: id, object: %{id: pre_loaded}, activity: _} = assigns,
        socket
      )
      when is_binary(id) and id == pre_loaded do
    debug(pre_loaded, "object pre_loaded")
    init_object_assigns(assigns.object, assigns.activity, assigns, socket, l("Discussion"))
  end

  def load_object_assigns(
        %{post_id: id, object: %{id: pre_loaded}, activity: _} = assigns,
        socket
      )
      when is_binary(id) and id == pre_loaded do
    debug(pre_loaded, "post pre_loaded")
    init_object_assigns(assigns.object, assigns.activity, assigns, socket, l("Post"))
  end

  def load_object_assigns(%{post_id: id} = assigns, socket) when is_binary(id) do
    current_user = current_user(socket)

    # debug(params, "PARAMS")
    # debug(url, "post url")
    with {:ok, object} <- Bonfire.Social.Posts.read(ulid!(id), socket) do
      {activity, object} = Map.pop(object, :activity)

      init_object_assigns(object, activity, assigns, socket, l("Post"))
    else
      _e ->
        {:error, "Not found"}
    end
  end

  def load_object_assigns(%{object_id: id} = assigns, socket) when is_binary(id) do
    current_user = current_user(socket)
    # debug(params, "PARAMS")
    with {:ok, object} <- Bonfire.Social.Objects.read(ulid!(id), current_user: current_user) do
      {activity, object} = Map.pop(object, :activity)
      {preloaded_object, activity} = Map.pop(activity, :object)

      init_object_assigns(
        Map.merge(object, preloaded_object || %{}),
        activity,
        assigns,
        socket,
        l("Discussion")
      )
    else
      _e ->
        case Bonfire.Common.Types.object_type_display(id) do
          type when is_binary(type) ->
            {:error, l("Sorry, you don't have permission to view this %{thing}", thing: type)}

          _ ->
            {:error, l("Not found")}
        end
    end
  end
end
