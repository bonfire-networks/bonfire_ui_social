defmodule Bonfire.UI.Social.ObjectThreadLoadLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, default: nil
  prop post_id, :string, default: nil
  prop object, :any, default: nil
  # prop page, :string, default: nil
  # prop page_title, :string, default: nil
  # prop show_reply_input, :boolean, default: false
  # prop search_placeholder, :string, default: nil
  prop thread_id, :string, default: nil
  # prop feed_id, :any, default: nil
  prop activity, :any, default: nil
  prop showing_within, :atom, default: :thread
  prop current_url, :string, default: nil
  prop thread_mode, :any, default: nil
  # prop reverse_order, :any, default: nil
  # prop participants, :any, default: []
  # prop smart_input_opts, :map, default: %{}
  # prop textarea_class, :css_class, default: nil
  # prop replied_activity_class, :css_class, default: nil
  prop replies, :any, default: nil
  prop threaded_replies, :any, default: nil
  # prop page_info, :any, default: nil
  # prop loading, :boolean, default: false

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

  def update(assigns, socket) do
    debug(assigns, "load object")

    {:ok,
     socket
     |> assign(assigns)
     |> Bonfire.Social.Objects.LiveHandler.load_object_assigns()}
  end

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
