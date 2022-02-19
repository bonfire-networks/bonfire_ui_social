defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :any
  prop object, :any
  prop verb, :string
  prop object_type_readable, :any
  prop flagged, :any
  slot extra_items, required: false
  slot admin_items, required: false

  def subject(assigns) do
    e(assigns, :object, :created, :creator, nil) || e(assigns, :activity, :subject, nil)
  end
  def subject_id(assigns) do
    e(subject(assigns), :id, nil)
  end
  def name(assigns) do
    e(subject(assigns), :profile, :name, l("this user"))
  end
end
