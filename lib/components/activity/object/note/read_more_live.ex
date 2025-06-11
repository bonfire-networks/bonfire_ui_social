defmodule Bonfire.UI.Social.Activity.ReadMoreLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop object, :any
  prop activity, :any, default: nil
  prop parent_id, :any, default: nil
end
