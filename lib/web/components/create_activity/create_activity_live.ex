defmodule Bonfire.UI.Social.CreateActivityLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  # prop target_component, :string
  prop create_activity_type, :string, default: "post"
  prop reply_to_id, :string
  prop reply_to_thread_id, :string
  prop smart_input_placeholder, :string, default: l("Write something...")
  prop smart_input_text, :string, default: "", required: false
  prop showing_within, :any
  prop with_editor, :boolean, required: false
  prop textarea_class, :string, default: "block w-full py-0 placeholder-base-content placeholder-opacity-70 bg-base-100 text-base-content border-0 resize-none focus:ring-0 sm:text-sm"


  def with_editor?(assigns) do
    case e(assigns, :with_editor, nil) do
      nil -> e(assigns, :showing_within, nil) != :thread && module_enabled?(Bonfire.Editor.Ck.Bubble)
      overide -> overide
    end
  end

  def activity_type_or_reply(assigns, create_activity_type) do
    IO.inspect(e(assigns, :reply_to_id, ""), label: "reply to id")
    IO.inspect(e(assigns, :reply_to_thread_id, ""), label: "reply_to_thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :reply_to_thread_id, "") !="",
    do: "reply",
    else: create_activity_type
  end
end
