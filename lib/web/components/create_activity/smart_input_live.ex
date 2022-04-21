defmodule Bonfire.UI.Social.SmartInputLive do
  use Bonfire.Web, :stateless_component

  # prop user_image, :string, required: true
  # prop target_component, :string
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop full_screen, :boolean, default: false

  prop showing_within, :any
  prop with_editor, :boolean, required: false
  prop textarea_class, :string, default: "textarea prose prose-sm"
  prop activity, :any
  prop object, :any

end
