defmodule  Bonfire.UI.Social.ViewObjectThreadLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop object_id, :string, default: nil
  prop post_id, :string, default: nil
  prop object, :any, default: nil
  prop page, :string, default: nil
  prop page_title, :string, default: nil
  prop show_reply_input, :boolean, default: false
  prop search_placeholder, :string, default: nil
  prop create_activity_type, :atom, default: nil
  prop to_boundaries, :list, default: nil
  prop to_circles, :list, default: nil
  prop smart_input_prompt, :string, default: nil
  prop smart_input_text, :string, default: nil
  prop reply_to_id, :string, default: nil
  prop thread_id, :string, default: nil
  prop feed_id, :any, default: nil
  prop activity, :any, default: nil
  prop showing_within, :any, default: :thread
  prop url, :string, default: nil
  prop thread_mode, :any, default: nil
  prop reverse_order, :any, default: nil
  prop participants, :any, default: []
  prop textarea_class, :css_class, default: nil
  prop replied_activity_class, :css_class, default: nil
  prop replies, :any, default: nil
  prop threaded_replies, :any, default: nil
  prop page_info, :any, default: nil

  def update(%{object_id: id} = assigns, %{assigns: %{object_id: previously_loaded, object: %{}}} = socket) when is_binary(id) and id==previously_loaded do
    debug("object previously_loaded")
    {:noreply, assign(socket, assigns)}
  end
  def update(%{post_id: id} = assigns, %{assigns: %{object_id: previously_loaded, object: %{}}} = socket) when is_binary(id) and id==previously_loaded do
    debug("post previously_loaded")
    {:noreply, assign(socket, assigns)}
  end

  def update(assigns, socket) do
    debug("load object")
    {:ok, socket
      |> assign(assigns)
      |> Bonfire.Social.Objects.LiveHandler.load_object_assigns()
    }
  end


end
