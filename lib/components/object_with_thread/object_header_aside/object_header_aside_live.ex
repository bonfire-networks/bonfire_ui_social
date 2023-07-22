defmodule Bonfire.UI.Social.ObjectHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, default: nil
  prop participants, :any, default: nil
  prop thread_id, :string, default: nil
  prop activity, :any, default: %{}
  prop showing_within, :atom, default: nil
end
