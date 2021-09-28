defmodule Bonfire.UI.Social.ProfileViewLive do
  use Bonfire.Web, :stateless_component


  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "timeline"
  prop smart_input, :boolean, required: true
  prop has_private_tab, :boolean, required: true
  prop smart_input_placeholder, :string
  prop smart_input_text, :string
  prop search_placholder, :string
  prop feed_title, :string
  prop user, :map

  def tab(selected_tab) do
    case maybe_str_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
  end
end
