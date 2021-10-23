defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :map
  prop verb, :string
  prop verb_display, :string 
  prop showing_within, :any
end
