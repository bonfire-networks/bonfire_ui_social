defmodule Bonfire.UI.Social.Activity.CharacterLive do
  use Bonfire.Web, :stateless_component


  prop object, :any
  prop activity, :any
  prop verb_display, :string
  prop permalink, :string
  prop date_ago, :string
end
