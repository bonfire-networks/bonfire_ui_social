defmodule Bonfire.UI.Social.SidebarLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Surface.Components.LivePatch

  # prop name, :string, required: true
  # prop user_image, :string, required: true
  # prop username, :string, required: true
  prop page, :string, required: true
  # need to pass down props for SmartInput:
  prop reply_to_id, :string, default: ""
  prop thread_id, :string, default: "", required: false
  prop create_activity_type, :any
  prop showing_within, :any
  prop to_circles, :list
  prop smart_input_prompt, :string, required: false
  prop smart_input_text, :string, required: false
  prop sidebar_widgets, :list, default: []

end
