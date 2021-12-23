defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.Web, :stateless_component


  prop activity, :map
  prop verb, :string
  prop verb_display, :string
  prop showing_within, :any
end
