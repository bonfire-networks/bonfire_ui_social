defmodule Bonfire.Social.Objects.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where
  alias Bonfire.Social.Objects

  def handle_event("set_name", %{"id" => id, "name" => name} = params, socket) do
    with {:ok, _} <- Objects.set_name(e(params, "id") || e(socket.assigns, :object, nil), name, current_user: current_user(socket)) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign(page_title: name)
        |> assign_flash(:info, l "Name updated!")
      }
    end
  end

  def handle_event("tag", %{"tags" => tags} = params, socket) do
    with {:ok, _} <- Bonfire.Social.Tags.maybe_tag(current_user(socket), e(params, "id", nil) || e(socket.assigns, :object, nil), tags) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign_flash(:info, l "Tagged!")
      }
    end
  end

  def handle_event("delete", %{"id"=> id} = params, socket) do
    with {:ok, _} <- Objects.delete(id, current_user: current_user(socket)) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
        socket
        |> assign_flash(:info, l "Deleted!")
      }
    end
  end

  def load_object(socket), do: load_object(socket.assigns, socket)

  def load_object(%{post_id: id} = assigns, socket) when is_binary(id) do
    current_user = current_user(socket)

    # debug(params, "PARAMS")
    # debug(url, "post url")
    with {:ok, post} <- Bonfire.Social.Posts.read(ulid(id), socket) do

      {activity, post} = Map.pop(post, :activity)
      activity = Bonfire.Social.Activities.activity_preloads(activity, :all, current_user: current_user)
      # debug(post, "the post")
      # debug(activity, "the activity")
      # following = if current_user && module_enabled?(Bonfire.Social.Follows) && Bonfire.Social.Follows.following?(current_user, post), do: [post.id]

      author = ( e(activity, :subject, nil) || e(activity, :created, :creator, nil) || e(activity, :object, :created, :creator, nil) ) #|> debug("object author")

      thread_id = e(activity, :replied, :thread_id, id)
      reply_to_id = e(assigns, :reply_to_id, id) #|> debug("reply_to_id")

      # smart_input_prompt = l("Reply to post:")<>" "<>Text.text_only(e(post, :post_content, :name, e(post, :post_content, :summary, e(post, :post_content, :html_body, reply_to_id))))
      smart_input_prompt = l("Reply")

      participants = Bonfire.Social.Threads.list_participants(activity, thread_id, current_user: current_user)

      to_circles = if length(participants)>0, do: Enum.map(participants, & {e(&1, :character, :username, l "someone"), e(&1, :id, nil)})

      # names = if length(participants)>0, do: Enum.map_join(participants, ", ", &e(&1, :profile, :name, e(&1, :character, :username, l "someone else")))

      mentions = if length(participants)>0, do: Enum.map_join(participants |> Enum.reject(&( e(&1, :character, :id, nil) == ulid(current_user) )), " ", & "@"<>e(&1, :character, :username, ""))<>" "

      page_title = e(activity, :replied, :thread, :named, :name, l("Post"))

      socket
      |> assign(
        object_id: id,
        object_loaded: true,
        activity: activity,
        object: post,
        # url: url,
        participants: participants,
        no_index: !Bonfire.Me.Settings.get([Bonfire.Me.Users, :discoverable], true, current_user: author),
        thread_id: e(post, :id, nil),
        reply_to_id: reply_to_id,
        page_title: page_title,
        smart_input_text: mentions,
        to_circles: to_circles,
        page_header_aside: [
          {Bonfire.UI.Social.ObjectHeaderAsideLive, [
            page_title: page_title,
            participants: participants,
            thread_id: thread_id,
            object: activity,
          ]}
        ],
      )

    else _e ->
      {:error, "Not found"}
    end
  end

  def load_object(%{object_id: id} = assigns, socket) when is_binary(id) do
    # FIXME: consolidate common code

    current_user = current_user(socket)
    # debug(params, "PARAMS")
    with {:ok, object} <- Bonfire.Social.Objects.read(ulid(id), socket) do

      {activity, object} = Map.pop(object, :activity)
      {preloaded_object, activity} = Map.pop(activity, :object)

      activity = Bonfire.Social.Activities.activity_preloads(activity, :all, current_user: current_user)

      author = ( e(activity, :subject, nil) || e(activity, :created, :creator, nil) || e(activity, :object, :created, :creator, nil) ) #|> debug("object author")

      thread_id = e(activity, :replied, :thread_id, id)

      # following = if current_user && module_enabled?(Bonfire.Social.Follows) do
      #   a = if Bonfire.Social.Follows.following?(current_user, object), do: object.id
      #   b = if thread_id && Bonfire.Social.Follows.following?(current_user, thread_id), do: thread_id
      #   [a, b]
      # end

      reply_to_id = e(assigns, :reply_to_id, id)

      participants = Bonfire.Social.Threads.list_participants(activity, thread_id, current_user: current_user)

      to_circles = if length(participants)>0, do: Enum.map(participants, & {e(&1, :character, :username, l "someone"), e(&1, :id, nil)})

      # names = if length(participants)>0, do: Enum.map_join(participants, ", ", &e(&1, :profile, :name, e(&1, :character, :username, l "someone else")))
      mentions = if length(participants)>0, do: Enum.map_join(participants |> Enum.reject(&( e(&1, :character, :id, nil) == ulid(current_user) )), " ", & "@"<>e(&1, :character, :username, ""))<>" "

      page_title = e(activity, :replied, :thread, :named, :name, nil)

      socket
      |> assign(
        object_id: id,
        object_loaded: true,
        activity: activity,
        object: Map.merge(object, preloaded_object || %{}),
        # url: url,
        participants: participants,
        page_title: page_title,
        no_index: !Bonfire.Me.Settings.get([Bonfire.Me.Users, :discoverable], true, current_user: author),
        reply_to_id: reply_to_id,
        thread_id: ulid(object),
        smart_input_text: mentions,
        to_circles: to_circles,
        page_header_aside: [
          {Bonfire.UI.Social.ObjectHeaderAsideLive, [
            page_title: page_title,
            participants: participants,
            thread_id: thread_id,
            object: activity,
          ]}
        ]
      )

    else _e ->
      {:error, l("Not found (or you don't have permission to view this)")}
    end
  end

end
