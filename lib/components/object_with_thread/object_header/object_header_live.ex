defmodule  Bonfire.UI.Social.ObjectHeaderLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string
  prop participants, :any, default: []
  prop thread_id, :string, default: nil
  prop object, :any
  prop thread_mode, :string, default: nil
  

end