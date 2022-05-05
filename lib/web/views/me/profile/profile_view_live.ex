defmodule Bonfire.UI.Social.ProfileViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "timeline"
  prop smart_input, :boolean, required: true
  prop reply_to_id, :string
  prop thread_id, :string
  prop create_activity_type, :any
  prop to_circles, :list
  prop smart_input_prompt, :string
  prop smart_input_text, :string
  prop search_placholder, :string
  prop feed_title, :string
  prop user, :map
  prop feed, :list
  prop page_info, :any

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
  end
end
