defmodule Bonfire.UI.Social.SmartInputLive do
  use Bonfire.Web, :stateless_component

  # prop user_image, :string, required: true
  prop target_component, :string
  prop smart_input_private, :boolean, default: nil
  prop create_activity_type, :string, default: nil
  prop reply_to_id, :string, default: ""
  prop reply_to_thread_id, :string, default: "", required: false
  prop smart_input_placeholder, :string, default: "Write something...", required: false
  prop smart_input_text, :string, default: "", required: false

end
