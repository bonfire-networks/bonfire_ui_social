defmodule Bonfire.UI.Social.ObjectHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop participants, :any, default: []
  prop thread_id, :string, default: nil
  prop activity, :any, default: %{}
end
