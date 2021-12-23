defmodule Bonfire.UI.Social.Activity.CreatorLive do
  use Bonfire.Web, :stateless_component


  prop profile, :any
  prop character, :any
  prop permalink, :string
  prop date_ago, :string
  prop created_verb_display, :string
end
