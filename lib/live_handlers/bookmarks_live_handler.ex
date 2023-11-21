defmodule Bonfire.Social.Bookmarks.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle

  # bookmark in LV stateful
  def handle_event(
        "bookmark",
        %{"direction" => "up"} = params,
        %{assigns: %{object: object}} = socket
      ) do
    do_bookmark(object, params, socket)
  end

  # bookmark in LV
  def handle_event("bookmark", %{"direction" => "up", "id" => id} = params, socket) do
    do_bookmark(id, params, socket)
  end

  # unbookmark in LV
  def handle_event("bookmark", %{"direction" => "down", "id" => id} = params, socket) do
    with _ <- Bonfire.Social.Bookmarks.unbookmark(current_user_required!(socket), id) do
      bookmark_action(id, false, params, socket)
    end
  end

  def do_bookmark(object, params, socket) do
    with {:ok, current_user} <- current_user_or_remote_interaction(socket, l("bookmark"), object),
         {:ok, _bookmark} <- Bonfire.Social.Bookmarks.bookmark(current_user, object) do
      bookmark_action(object, true, params, socket)
      |> debug("bookmarked")
    else
      {:error,
       %Ecto.Changeset{
         errors: [
           bookmarker_id: {"has already been taken", _}
         ]
       }} ->
        debug("previously bookmarked, but UI didn't know")
        bookmark_action(object, true, params, socket)

      {:error, e} ->
        error(e)

      other ->
        other
    end
  end

  defp bookmark_action(object, bookmarked?, params, socket) do
    ComponentID.send_updates(
      e(params, "component", Bonfire.UI.Social.BookmarkActionLive),
      ulid(object),
      my_bookmark: bookmarked?
    )

    {:noreply, socket}
  end

  def bookmarker_count(%{"current_count" => a}), do: a |> String.to_integer()
  def bookmarker_count(%{current_count: a}), do: a |> String.to_integer()
  # def bookmarker_count(%{assigns: a}), do: bookmarker_count(a)
  # def bookmarker_count(%{bookmark_count: bookmark_count}), do: bookmarker_count(bookmark_count)
  # def bookmarker_count(%{bookmarker_count: bookmarker_count}), do: bookmarker_count(bookmarker_count)
  # def bookmarker_count(bookmarker_count) when is_integer(bookmarker_count), do: bookmarker_count
  def bookmarker_count(_), do: 0

  def update_many(assigns_sockets, opts \\ []) do
    update_many_async(assigns_sockets, update_many_opts(opts))
  end

  def update_many_opts(opts \\ []) do
    opts ++
      [
        assigns_to_params_fn: &assigns_to_params/1,
        preload_fn: &do_preload/3
      ]
  end

  defp assigns_to_params(assigns) do
    object = e(assigns, :object, nil)

    %{
      component_id: assigns.id,
      object: object || e(assigns, :object_id, nil),
      object_id: e(assigns, :object_id, nil) || ulid(object),
      previous_my_bookmark: e(assigns, :my_bookmark, nil),
      previous_bookmark_count: e(assigns, :bookmark_count, nil)
    }
  end

  defp do_preload(list_of_components, list_of_ids, current_user) do
    my_states = if current_user, do: do_list_my_bookmarked(current_user, list_of_ids), else: %{}

    # debug(my_states, "my_bookmarks")

    objects_counts =
      if Bonfire.Common.Settings.get([:ui, :show_activity_counts], nil,
           current_user: current_user
         ) do
        list_of_components
        |> Enum.map(fn %{object: object} ->
          object
        end)
        |> filter_empty([])
        |> debug("list_of_objects")
        |> repo().maybe_preload(:bookmark_count, follow_pointers: false)
        |> Map.new(fn o -> {e(o, :id, nil), e(o, :bookmark_count, :object_count, nil)} end)

        # |> debug("bookmark_counts")
      end

    list_of_components
    |> Map.new(fn component ->
      {component.component_id,
       %{
         my_bookmark:
           Map.get(my_states, component.object_id) || component.previous_my_bookmark || false,
         bookmark_count:
           e(objects_counts, component.object_id, nil) || component.previous_bookmark_count
       }}
    end)
  end

  # defp list_my_bookmarked(current_user, objects) when is_list(objects) do
  #   Cache.cached_preloads_for_objects("my_bookmark:#{ulid(current_user)}:", objects, fn list_of_ids -> do_list_my_bookmarked(current_user, list_of_ids) end)
  # end

  defp do_list_my_bookmarked(current_user, list_of_ids)
       when is_list(list_of_ids) and length(list_of_ids) > 0 do
    Bonfire.Social.Bookmarks.get!(current_user, list_of_ids,
      preload: false,
      skip_boundary_check: true
    )
    |> debug()
    |> Map.new(fn l -> {e(l, :edge, :object_id, nil), true} end)
  end

  defp do_list_my_bookmarked(_, _objects), do: %{}
end
