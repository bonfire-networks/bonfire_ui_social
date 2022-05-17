defmodule Bonfire.UI.Social.MessagesViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

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
  prop activity, :any
  prop object, :any
  prop url, :any
  prop participants, :any
end
