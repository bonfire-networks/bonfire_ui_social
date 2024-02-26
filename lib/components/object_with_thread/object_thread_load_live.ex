defmodule Bonfire.UI.Social.ObjectThreadLoadLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, default: nil
  prop post_id, :string, default: nil
  prop object, :any, default: nil
  # prop page, :string, default: nil
  prop thread_title, :string, default: nil
  # prop show_reply_input, :boolean, default: false
  # prop search_placeholder, :string, default: nil
  prop thread_id, :string, default: nil
  # prop feed_id, :any, default: nil
  prop activity, :any, default: nil
  prop showing_within, :atom, default: :thread
  prop current_url, :string, default: nil
  prop thread_mode, :any, default: nil
  # prop sort_order, :any, default: nil
  prop participants, :any, default: nil
  # prop smart_input_opts, :map, default: %{}
  # prop textarea_class, :css_class, default: nil
  # prop replied_activity_class, :css_class, default: nil
  prop replies, :any, default: nil
  # prop page_info, :any, default: nil
  # prop loading, :boolean, default: false
  prop activity_inception, :any, default: nil

  def update(%{post_id: id} = assigns, %{assigns: %{object: %{id: previously_loaded}}} = socket)
      when is_binary(id) and id == previously_loaded do
    debug(previously_loaded, "post previously_loaded")
    {:ok, assign(socket, assigns)}
  end

  def update(%{object_id: id} = assigns, %{assigns: %{object: %{id: previously_loaded}}} = socket)
      when is_binary(id) and id == previously_loaded do
    debug(previously_loaded, "object previously_loaded")
    {:ok, assign(socket, assigns)}
  end

  def update(%{object_id: id} = assigns, %{assigns: %{object: %{id: previously_loaded}}} = socket)
      when is_binary(id) and id == previously_loaded do
    debug(previously_loaded, "object previously_loaded")
    {:ok, assign(socket, assigns)}
  end

  def update(assigns, socket) do
    debug(assigns, "load object")

    socket = socket |> assign(assigns)

    with %Phoenix.LiveView.Socket{} = socket <-
           Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket) |> debug("zzsildj") do
      {:ok, socket}
    else
      {:error, e} ->
        {:ok, assign_error(socket, e)}

      other ->
        error(other)
        {:ok, socket}
    end
  end
end
