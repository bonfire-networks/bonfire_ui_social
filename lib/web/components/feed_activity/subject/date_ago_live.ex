defmodule Bonfire.UI.Social.Activity.DateAgoLive do
  use Bonfire.Web, :stateless_component

  prop verb_display, :string
  prop date_ago, :any
  prop viewing_main_object, :boolean 
  prop permalink, :string
end
