defmodule Bonfire.UI.Social.ThreadEmptyLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop showing_within, :atom, default: :thread
end
