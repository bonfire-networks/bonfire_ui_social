defmodule Bonfire.UI.Social.Activity.SubjectRepliedLive do
  use Bonfire.Web, :stateless_component


  prop activity, :map
  prop permalink, :string
  prop date_ago, :string
end
