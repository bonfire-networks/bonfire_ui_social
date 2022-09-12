defmodule Bonfire.Social.Likes.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  # like in LV stateful
  def handle_event(
        "like",
        %{"direction" => "up"} = params,
        %{assigns: %{object: object}} = socket
      ) do
    do_like(object, params, socket)
  end

  # like in LV
  def handle_event("like", %{"direction" => "up", "id" => id} = params, socket) do
    do_like(id, params, socket)
  end

  # unlike in LV
  def handle_event("like", %{"direction" => "down", "id" => id} = params, socket) do
    with _ <- Bonfire.Social.Likes.unlike(current_user(socket), id) do
      like_action(id, false, params, socket)
    end
  end

  def do_like(object, params, socket) do
    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("like"), object),
         {:ok, _like} <- Bonfire.Social.Likes.like(current_user, object) do
      like_action(object, true, params, socket)
      |> debug("liked")
    else
      {:error,
       %Ecto.Changeset{
         errors: [
           liker_id: {"has already been taken", _}
         ]
       }} ->
        debug("previously liked, but UI didn't know")
        like_action(object, true, params, socket)

      {:error, e} ->
        error(e)

      other ->
        other
    end
  end

  defp like_action(object, liked?, params, socket) do
    ComponentID.send_updates(
      e(params, "component", Bonfire.UI.Common.LikeActionLive),
      ulid(object),
      my_like: liked?
    )

    {:noreply, socket}
  end

  def liker_count(%{"current_count" => a}), do: a |> String.to_integer()
  def liker_count(%{current_count: a}), do: a |> String.to_integer()
  # def liker_count(%{assigns: a}), do: liker_count(a)
  # def liker_count(%{like_count: like_count}), do: liker_count(like_count)
  # def liker_count(%{liker_count: liker_count}), do: liker_count(liker_count)
  # def liker_count(liker_count) when is_integer(liker_count), do: liker_count
  def liker_count(_), do: 0

  def preload(list_of_assigns) do
    current_user = current_user(List.first(list_of_assigns))
    # |> info("current_user")

    # debug(list_of_assigns, "list of assign:")
    list_of_objects =
      list_of_assigns
      |> Enum.map(&e(&1, :object, nil))

    # |> debug("list_of_objects")

    list_of_ids =
      list_of_objects
      |> Enum.map(&e(&1, :id, nil))
      |> filter_empty([])

    # |> debug("list_of_ids")

    my_states = if current_user, do: do_list_my_liked(current_user, list_of_ids), else: %{}

    # info(my_states, "my_likes")

    objects_counts =
      if Bonfire.Me.Settings.get([:ui, :show_activity_counts], nil, current_user: current_user) do
        list_of_objects
        |> repo().maybe_preload(:like_count, follow_pointers: false)
        |> Map.new(fn o -> {e(o, :id, nil), e(o, :like_count, :object_count, nil)} end)

        # |> debug("like_counts")
      end

    list_of_assigns
    |> Enum.map(fn assigns ->
      object_id = e(assigns, :object, :id, nil)

      value =
        if current_user,
          do: Map.get(my_states, object_id),
          else: Map.get(List.first(list_of_assigns), :my_like)

      assigns
      |> Map.put(
        :my_like,
        value
      )
      |> Map.put(
        :like_count,
        e(objects_counts, object_id, nil)
      )
    end)
  end

  # defp list_my_liked(current_user, objects) when is_list(objects) do
  #   Cache.cached_preloads_for_objects("my_like:#{ulid(current_user)}:", objects, fn list_of_ids -> do_list_my_liked(current_user, list_of_ids) end)
  # end

  defp do_list_my_liked(current_user, list_of_ids)
       when is_list(list_of_ids) and length(list_of_ids) > 0 do
    Bonfire.Social.Likes.get!(current_user, list_of_ids, preload: false)
    |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end)
  end

  defp do_list_my_liked(_, _objects), do: %{}
end
