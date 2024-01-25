defmodule Bonfire.UI.Social.Activity.LabelledLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop labelled, :any, default: nil
  prop showing_within, :atom, default: nil
  prop class, :css_class, default: ["flex items-center -ml-6 justify-start pb-2 mb-2"]
end
