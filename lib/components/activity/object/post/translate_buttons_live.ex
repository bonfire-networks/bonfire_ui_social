defmodule Bonfire.UI.Social.Activity.TranslateButtonsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity, :any, default: nil
  prop parent_id, :any, default: nil
end
