defmodule Bonfire.UI.Social.Activity.RepliedDateAgoLive do
  use Bonfire.Web, :stateless_component

  prop verb_display, :string
  prop date_ago, :any
  prop permalink, :string
end
