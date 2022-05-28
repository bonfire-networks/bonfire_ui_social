defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive

  prop activity, :any
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop object_type_readable, :any
  prop flagged, :any
  slot extra_items, required: false
  slot admin_items, required: false
  prop showing_within, :any, default: :feed

  def subject(assigns) do
    e(assigns, :activity, :subject, nil) || e(assigns, :object, :created, :creator, nil)
  end
  def subject_id(assigns) do
    e(subject(assigns), :id, nil)
  end
  def name(assigns) do
    e(subject(assigns), :profile, :name, l("this user"))
  end
end