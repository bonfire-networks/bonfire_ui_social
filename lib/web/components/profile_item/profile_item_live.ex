defmodule Bonfire.UI.Social.ProfileItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any
  prop character, :any
  prop class, :string
  prop show_controls, :list, default: [:follow]

  slot default, required: false
end
