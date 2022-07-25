defmodule Bonfire.UI.Social.WriteEditorLive do
  use Bonfire.UI.Common.Web, :stateless_component
  use Bonfire.Common.Utils
  alias Surface.Components.Form.TextArea
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Inputs

  prop field_name, :string, default: "post[post_content][html_body]", required: false
  prop create_activity_type, :any
  prop smart_input_prompt, :string, default: ""
  prop smart_input_text, :string, default: "", required: false
  prop showing_within, :string
  prop with_rich_editor, :boolean, default: true, required: false
  prop insert_text, :string
  prop thread_mode, :atom
  # Classes to customize the smart input appearance
  prop textarea_class, :css_class


  def use_rich_editor?(with_rich_editor, context) do
    with_rich_editor |> debug !=false && !Bonfire.Me.Settings.get([:ui, :rich_text_editor_disabled], false, context)
  end

  def rich_editor_module(with_rich_editor, context) do
    if use_rich_editor?(with_rich_editor, context) |> debug do
      default = Bonfire.Editor.Quill
      module = Bonfire.Me.Settings.get([:ui, :rich_text_editor], default, context)

      if module_enabled?(module), do: module, else: error(nil, "#{module} is not available or enabled")
    end
  end

end
