defmodule Bonfire.Social.Likes.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Where

  def handle_event("like", %{"direction"=>"up"} = params, %{assigns: %{object: object}} = socket) do # like in LV stateful
    do_like(object, params, socket)
  end

  def handle_event("like", %{"direction"=>"up", "id"=> id} = params, socket) do # like in LV
    do_like(id, params, socket)
  end

  def handle_event("like", %{"direction"=>"down", "id"=> id} = params, socket) do # unlike in LV
    with _ <- Bonfire.Social.Likes.unlike(current_user(socket), id) do
      like_action(id, false, params, socket)
    end
  end

  def do_like(object, params, socket) do
    with %{id: _} = current_user <- current_user(socket),
         {:ok, _like} <- Bonfire.Social.Likes.like(current_user, object) do
      like_action(object, true, params, socket)

    else {:error, %Ecto.Changeset{errors: [
       liker_id: {"has already been taken",
        _}
     ]}} ->
      debug("previously liked, but UI didn't know")
      like_action(object, true, params, socket)
    end
  end

  defp like_action(object, liked?, params, socket) do
    ComponentID.send_assigns(
      e(params, "component", Bonfire.UI.Common.LikeActionLive),
      ulid(object),
      [my_like: liked?],
      socket)
  end

  def liker_count(%{"current_count"=> a}), do: a |> String.to_integer
  def liker_count(%{current_count: a}), do: a |> String.to_integer
  # def liker_count(%{assigns: a}), do: liker_count(a)
  # def liker_count(%{like_count: like_count}), do: liker_count(like_count)
  # def liker_count(%{liker_count: liker_count}), do: liker_count(liker_count)
  # def liker_count(liker_count) when is_integer(liker_count), do: liker_count
  def liker_count(_), do: 0

  def preload(list_of_assigns) do
    current_user = current_user(List.first(list_of_assigns))
    # |> info("current_user")

    # debug(list_of_assigns, "list of assign:")
    list_of_objects = list_of_assigns
    |> Enum.map(& e(&1, :object, nil))
    |> repo().maybe_preload(:like_count)
    # |> debug("list_of_objects")

    list_of_ids = list_of_objects
    |> Enum.map(& e(&1, :id, nil))
    |> filter_empty([])
    # |> debug("list_of_ids")

    my_states = if current_user, do: Bonfire.Social.Likes.get!(current_user, list_of_ids, preload: false) |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end), else: %{}

    # info(my_states, "my_likes")

    objects_counts = list_of_objects |> Map.new(fn o -> {e(o, :id, nil), e(o, :like_count, :object_count, nil)} end)
    # |> debug("like_counts")

    list_of_assigns
    |> Enum.map(fn assigns ->
      object_id = e(assigns, :object, :id, nil)
      value = if current_user, do: Map.get(my_states, object_id), else: Map.get(List.first(list_of_assigns), :my_like)

      assigns
      |> Map.put(
        :my_like,
        value
      )
      |> Map.put(
        :like_count,
        Map.get(objects_counts, object_id)
      )
    end)
  end

end
