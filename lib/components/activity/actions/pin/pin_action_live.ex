defmodule Bonfire.UI.Social.PinActionLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop class, :css_class, default: "btn btn-ghost btn-circle btn-sm"
  prop scope, :atom, default: nil
  # prop showing_within, :any, default: nil
end
