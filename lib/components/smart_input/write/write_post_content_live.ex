defmodule Bonfire.UI.Social.WritePostContentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs
  alias Bonfire.UI.Common.WriteEditorLive

  # prop target_component, :string, default: nil
  prop reply_to_id, :string, default: nil
  prop context_id, :string, default: nil
  prop create_object_type, :atom, default: nil
  prop to_boundaries, :list, default: []
  prop to_circles, :list, default: []
  prop smart_input_prompt, :string, default: nil
  prop smart_input_text, :string, required: false
  prop showing_within, :string, default: nil
  prop with_rich_editor, :boolean, default: true
  prop insert_text, :string, default: nil
  prop preloaded_recipients, :any, default: nil
  prop uploads, :any, default: nil
  prop thread_mode, :atom, default: nil
  prop uploaded_files, :list, default: nil
  prop title_prompt, :string, default: nil
  prop show_select_recipients, :boolean, default: false
  prop open_boundaries, :boolean, default: false
  prop boundaries_modal_id, :string, default: :sidebar_composer

  # Classes to customize the smart input appearance
  prop textarea_container_class, :css_class
  prop textarea_container_class_alpine, :string
  prop textarea_class, :css_class
  prop replied_activity_class, :css_class

  def handler(assigns) do
    if is_messaging?(assigns),
      do: "Bonfire.Social.Messages:send",
      else: "Bonfire.Social.Posts:post"
  end
end
