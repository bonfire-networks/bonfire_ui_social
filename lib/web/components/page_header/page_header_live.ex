defmodule Bonfire.UI.Social.PageHeaderLive do
  use Surface.Component

  prop current_user, :any, required: true # WIP Passing a boolean rather than the whole user object
  prop name, :string, required: true
  prop user_image, :string, required: true
  prop username, :string, required: true
  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true

  prop smart_input_private, :boolean, default: nil
  prop create_activity_type, :string, default: nil
  prop reply_to_id, :string, default: ""
  prop reply_to_thread_id, :string
  prop smart_input_placeholder, :string, default: "Write something meaningful"
  prop smart_input_text, :string



end
