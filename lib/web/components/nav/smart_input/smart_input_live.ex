defmodule Bonfire.UI.Social.SmartInputLive do
  use Surface.Component

  prop user_image, :string, required: true
  prop target_component, :string
  prop smart_input_private, :boolean, default: nil
  prop create_activity_type, :string, default: nil
  prop reply_to_id, :string, default: ""
  prop reply_to_thread_id, :string
  prop smart_input_placeholder, :string
  prop smart_input_text, :string

end
