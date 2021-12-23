defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.Web, :stateless_component


  prop activity, :map
  prop profile, :map
  prop character, :map
  prop date_ago, :any
  prop permalink, :string
  prop verb_display, :string
end
