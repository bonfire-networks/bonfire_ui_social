defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.Web, :stateless_component
  import Bonfire.UI.Social.Integration

  prop activity, :any
  prop object, :any
  prop flagged, :any

  def subject(activity) do
    e(activity, :creator, nil) || e(activity, :subject, nil)
  end
  def subject_id(activity) do
    e(subject(activity), :id, nil)
  end
  def name(activity) do
    e(subject(activity), :profile, :name, l("this user"))
  end
end
