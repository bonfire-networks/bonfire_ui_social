defmodule  Bonfire.UI.Social.ObjectHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string
  prop participants, :any, default: []
  prop thread_id, :string, default: nil
  prop label, :string, default: nil
  prop object, :any


end
