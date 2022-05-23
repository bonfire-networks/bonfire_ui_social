defmodule Bonfire.UI.Social.Activity.SubjectRepliedLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :map
  prop object, :any
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any, default: :feed
  prop object_boundary, :any, default: nil

end
