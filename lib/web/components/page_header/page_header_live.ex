defmodule Bonfire.UI.Social.PageHeaderLive do
  use Bonfire.Web, :stateless_component

  prop page_title, :string, required: true
  prop before, :boolean, default: false
  slot default

end
