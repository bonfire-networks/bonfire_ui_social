defmodule Bonfire.UI.Social.WritePostContentLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  # alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  # alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs
  alias Bonfire.UI.Common.WriteEditorLive

  # prop target_component, :string, default: nil
  prop reply_to_id, :any, default: nil
  prop context_id, :string, default: nil
  prop create_object_type, :any, default: nil
  prop to_boundaries, :any, default: nil
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop mentions, :list, default: []
  prop smart_input_opts, :map, default: %{}
  prop showing_within, :atom, default: nil
  prop insert_text, :string, default: nil
  prop preloaded_recipients, :any, default: nil
  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: nil
  prop title_prompt, :string, default: nil

  prop open_boundaries, :boolean, default: false
  prop boundaries_modal_id, :string, default: :sidebar_composer
  prop reset_smart_input, :boolean, default: false

  prop preview_boundary_for_id, :any, default: nil
  prop preview_boundary_for_username, :any, default: nil
  prop preview_boundary_verbs, :any, default: nil

  # Classes to customize the smart input appearance
  prop textarea_container_class, :css_class
  prop textarea_container_class_alpine, :string
  prop textarea_class, :css_class
  prop replied_activity_class, :css_class

  def handler(create_object_type) do
    if create_object_type == :message,
      do: "Bonfire.Social.Messages:send",
      else: "Bonfire.Social.Posts:post"
  end
end
