defmodule Bonfire.UI.Social.PageHeaderLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop smart_input, :boolean, required: true


end
