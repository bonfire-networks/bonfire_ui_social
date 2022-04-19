defmodule Bonfire.UI.Social.PrivateViewLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true
  prop feed, :list
  prop tab_id, :string, default: nil
end
