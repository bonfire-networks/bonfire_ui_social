defmodule Bonfire.UI.Social.PrivateViewLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  # prop smart_input, :boolean, required: true
  prop feed, :list
  prop tab_id, :string
  prop users, :list
  prop thread_id, :any
  prop smart_input_prompt, :any
  prop smart_input_text, :any
  prop to_circles, :list
end
