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
  prop activity, :any
  prop object, :any
  
  # Classes to customize the smart input appearance 
  prop textarea_class, :string, default: "h-32 textarea prose prose-sm"
  prop smart_input_class, :string, default: "rounded-md shadow bg-base-100"
  prop replied_activity_class, :string, default: "relative p-3 mb-2 rounded bg-base-100 hover:bg-base-100 hover:bg-opacity-100 showing_within:create_activity_form"
end
