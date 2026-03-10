defmodule Bonfire.UI.Social.Activity.LabelledLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop label, :any, default: nil
  prop label_id, :any, default: nil
  # prop activity, :any, default: nil
  prop showing_within, :atom, default: nil
  prop class, :css_class, default: ["flex items-center -ml-8 justify-start -ml-[30px]"]
end
