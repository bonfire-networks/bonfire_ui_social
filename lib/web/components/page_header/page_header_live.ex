defmodule Bonfire.UI.Social.PageHeaderLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true
  prop create_activity_type, :any, required: false


end
