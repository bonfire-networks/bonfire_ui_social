defmodule Bonfire.UI.Social.WithoutSidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page, :any
  prop inner_content, :any
  # need to pass down props for SmartInput:
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
end
