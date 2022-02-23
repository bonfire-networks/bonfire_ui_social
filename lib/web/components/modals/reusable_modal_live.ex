defmodule Bonfire.UI.Social.ReusableModalLive do
  use Bonfire.Web, :stateful_component
  @moduledoc """
  The classic **modal**
  """

  @doc "The title of the modal. Only used if no title slot is passed."
  prop title_text, :string

  @doc "The classes of the title of the modal"
  prop title_class, :string, default: "font-bold text-lg"

  @doc "The classes of the open button for the modal. Only used if no open_btn slot is passed."
  prop open_btn_class, :string, default: "btn btn-primary"

  @doc "The classes of the close/cancel button on the modal. Only used if no close_btn slot is passed."
  prop cancel_btn_class, :string, default: "btn btn-secondary"

  @doc "Force modal to be open"
  prop show, :boolean, default: false

  @doc "Role should be :box for embeded the reusable modal in the live layout, otherwise leave empty."
  prop role, :atom, default: nil

  @doc """
  Additional attributes to add onto the modal wrapper
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<modal>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot open_btn
  slot action_btns
  slot cancel_btn
  slot default
  slot title


  def handle_event("close", _, socket) do
    {:noreply, assign(socket, show: false)}
  end

end
