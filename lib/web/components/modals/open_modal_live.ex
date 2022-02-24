defmodule Bonfire.UI.Social.OpenModalLive do
  @moduledoc """
  The classic **modal**
  """
  use Bonfire.Web, :stateful_component
  alias Bonfire.UI.Social.ReusableModalLive

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string

  @doc "The classes of the title of the modal"
  prop title_class, :string, default: "font-bold text-lg"

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :string, default: "btn btn-outline"

  @doc "Force modal to be open"
  prop show, :boolean, default: false


  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []


  @doc """
  Slots for the contents of the modal, title, buttons...
  """
  slot default
  slot open_btn
  slot action_btns
  slot cancel_btn
  slot title


  def open() do
    set(show: true)
  end

  def close() do
    set(show: false)
  end

  def set(assigns) when is_list(assigns) do
    send_update(ReusableModalLive, Keyword.put(assigns, :id, "modal"))
  end
  def set(assigns) when is_map(assigns) do
    send_update(ReusableModalLive, Map.put(assigns, :id, "modal"))
  end

  # Default event handlers

  def handle_event("open", _, socket) do
    socket = socket
    |> assign(show: true)

    set(socket.assigns)

    {:noreply, socket}
  end

  def handle_event("close", _, socket) do
    close()
    {:noreply, socket}
  end

end
