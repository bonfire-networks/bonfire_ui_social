defmodule Bonfire.UI.Social.Activity.SubjectRepliedLive do
  use Bonfire.Web, :stateless_component

  prop activity, :map
  prop object, :map
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any, default: :feed
end
