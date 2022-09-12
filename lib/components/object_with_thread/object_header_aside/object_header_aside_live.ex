defmodule Bonfire.UI.Social.ObjectHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: nil
  prop participants, :any, default: []
  prop thread_id, :string, default: nil
  prop label, :string, default: nil
  prop object, :any
  prop category_suggestions, :list, default: []
end
