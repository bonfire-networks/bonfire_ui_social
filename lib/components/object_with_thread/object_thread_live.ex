defmodule Bonfire.UI.Social.ObjectThreadLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :any, default: nil
  prop post_id, :any, default: nil
  prop object, :any, default: nil
  prop reply_id, :any, default: nil
  prop include_path_ids, :any, default: nil
  prop thread_title, :string, default: nil
  prop exclude_circles, :list, default: []
  prop thread_id, :string, default: nil
  prop feed_id, :any, default: nil
  prop activity, :any, default: nil
  prop showing_within, :atom, default: nil
  prop current_url, :string, default: nil
  prop thread_mode, :any, default: nil
  prop participants, :any, default: nil
  prop sort_by, :any, default: nil
  prop sort_order, :any, default: nil
  prop activity_inception, :any, default: nil
  prop hide_thread_stats, :boolean, default: false

  prop root_boosters, :list, default: []
  prop root_boost_count, :integer, default: 0

  prop loading, :any, default: nil
  prop replies, :any, default: nil
  prop threaded_replies, :any, default: nil
  prop page_info, :any, default: nil

  prop custom_preview, :any, default: nil

  # object type display name, set when the viewer lacks permission to read the
  # object (by `Objects.LiveHandler.not_found_fallback/3` or `check_read_permission/1`)
  prop object_not_permitted, :any, default: nil

  # when true, the rendered ActivityLive re-checks `:read` via `maybe_check_boundaries`
  # (nulls the object if the viewer may `:see` but not `:read` it) — used by the preview
  # modal so a see-only object's body isn't exposed.
  prop check_object_boundary, :boolean, default: false

  # NOTE: the update callback will only run when this is being used as a stateful component (i.e. in some cases in preview component)
  def update(%{post_id: id} = assigns, %{assigns: %{object: %{id: previously_loaded}}} = socket)
      when is_binary(id) and id == previously_loaded do
    debug(previously_loaded, "post previously_loaded")
    {:ok, assign(socket, Enums.filter_empty(assigns, []))}
  end

  def update(%{object_id: id} = assigns, %{assigns: %{object: %{id: previously_loaded}}} = socket)
      when is_binary(id) and id == previously_loaded do
    debug(previously_loaded, "object previously_loaded")
    {:ok, assign(socket, Enums.filter_empty(assigns, []))}
  end

  def update(assigns, socket) do
    debug(assigns, "maybe load object")

    socket = socket |> assign(assigns)

    with %Phoenix.LiveView.Socket{} = socket <-
           Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket)
           |> debug("loaded_object_assigns") do
      {:ok, check_read_permission(socket)}
    else
      {:error, e} ->
        {:ok, assign_error(socket, e)}

      other ->
        error(other)
        {:ok, socket}
    end
  end

  # When used as the preview modal (`check_object_boundary` set by
  # `thread_preview_modal_assigns`), the object may arrive pre-loaded from a feed
  # where the viewer only needed `:see` — re-check `:read` so they don't get the
  # body of something they may only discover. Guests never reach this (the modal
  # trigger requires login; guest page loads are already `:read`-boundarised).
  defp check_read_permission(socket) do
    object = e(assigns(socket), :object, nil)
    current_user = current_user(socket)

    if e(assigns(socket), :check_object_boundary, nil) == true and is_struct(object) and
         not is_nil(current_user) and
         Bonfire.Boundaries.load_pointers(id(object),
           current_user: current_user,
           verbs: [:read],
           ids_only: true
         )
         |> Enums.ids() == [] do
      socket
      |> assign(
        object_not_permitted:
          Bonfire.Common.Types.object_type_display(Bonfire.Common.Types.object_type(object)) ||
            l("post"),
        object: nil,
        activity: nil
      )
    else
      socket
    end
  end

  def render(assigns) do
    id =
      assigns[:thread_id] || id(assigns[:activity]) || assigns[:object_id] || assigns[:post_id] ||
        id(assigns[:object])

    assigns
    |> assign_new(:main_object_component_id, fn ->
      main_object_id =
        Bonfire.UI.Social.ActivityLive.component_id(
          id,
          "main_object",
          assigns[:activity_inception]
        )

      if assigns[:activity_inception] == "preview",
        do: "preview_#{main_object_id}",
        else: main_object_id
    end)
    |> render_sface()
  end
end
