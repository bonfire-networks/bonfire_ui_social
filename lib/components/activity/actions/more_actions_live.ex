defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive
  alias Bonfire.UI.Social.Integration

  prop activity, :any
  prop object, :any
  prop object_type, :any
  prop verb, :string
  prop object_type_readable, :any
  prop flagged, :any
  slot extra_items, required: false
  slot admin_items, required: false
  prop showing_within, :any, default: :feed

  def subject(activity, object) do
    e(activity, :subject, nil) || e(object, :created, :creator, nil)
  end

  def subject_id(activity, object) do
    ulid(subject(activity, object))
  end

  def name(activity, object) do
    e(subject(activity, object), :profile, :name, l("this user"))
  end
end
