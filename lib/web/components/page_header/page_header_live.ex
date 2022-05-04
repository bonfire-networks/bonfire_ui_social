defmodule Bonfire.UI.Social.PageHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, required: true
  prop before, :boolean, default: false, required: false
  slot default

end
