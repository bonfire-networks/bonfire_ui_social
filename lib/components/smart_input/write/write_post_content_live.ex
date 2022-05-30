defmodule Bonfire.UI.Social.WritePostContentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs
  alias Bonfire.UI.Social.WriteEditorLive

  # prop target_component, :string
  prop reply_to_id, :string
  prop thread_id, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string
  prop smart_input_text, :string, required: false
  prop showing_within, :any
  prop with_rich_editor, :boolean, default: true, required: false
  prop insert_text, :string
  prop uploads, :any
  prop thread_mode, :string
  prop uploaded_files, :list
  prop title_prompt, :string
  prop show_select_recipients, :boolean, default: false

  # Classes to customize the smart input appearance
  prop textarea_class, :string
  prop replied_activity_class, :string


  def activity_type_or_reply(assigns, create_activity_type) do
    debug(e(assigns, :reply_to_id, ""), "reply to id")
    debug(e(assigns, :thread_id, ""), "thread_id")
    if e(assigns, :reply_to_id, "") !="" or e(assigns, :thread_id, "") !="",
    do: "reply",
    else: "#{create_activity_type}"
  end

  def handler(activity_type) do
    if activity_type==:message, do: "Bonfire.Social.Messages:send", else: "Bonfire.Social.Posts:post"
  end

end
