defmodule Bonfire.UI.Social.CreateActivityLive do
  use Bonfire.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  # prop target_component, :string
  prop reply_to_id, :string
  prop thread_id, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string, default: ""
  prop smart_input_text, :string, default: "", required: false
  prop showing_within, :any
  prop with_editor, :boolean, required: false
  prop activity, :any
  prop object, :any
  prop insert_text, :string
  prop uploads, :any
  prop uploaded_files, :list

  # Classes to customize the smart input appearance
  prop textarea_class, :string
  prop smart_input_class, :string
  prop replied_activity_class, :string


  def with_editor?(assigns) do
    case e(assigns, :with_editor, nil) do
      nil -> e(assigns, :showing_within, nil) != :thread
      opt_assigned -> opt_assigned
    end && module_enabled?(Bonfire.Editor.Ck.Bubble)
  end

  def activity_type_or_reply(assigns, create_activity_type) do
    debug(e(assigns, :reply_to_id, ""), "reply to id")
    debug(e(assigns, :thread_id, ""), "thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :thread_id, "") !="",
    do: "reply",
    else: "#{create_activity_type}"
  end


end
