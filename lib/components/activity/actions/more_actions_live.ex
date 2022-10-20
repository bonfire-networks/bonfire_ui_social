defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Social.Integration
  alias Bonfire.UI.Common.OpenModalLive
  alias Bonfire.UI.Social.Integration

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop verb, :string, default: nil
  prop object_type_readable, :any
  prop flagged, :any, default: nil

  prop showing_within, :any, default: :feed

  slot extra_items, required: false
  slot admin_items, required: false

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
