defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Social.Integration
  # alias Bonfire.UI.Common.OpenModalLive
  # alias Bonfire.UI.Social.Integration

  alias Bonfire.Social.Feeds.LiveHandler

  prop activity, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop verb, :string, default: nil
  prop object_type_readable, :any, default: nil
  prop flagged, :any, default: nil
  prop activity_component_id, :string, default: nil
  prop thread_id, :string, required: true
  prop thread_mode, :any, default: nil
  prop thread_title, :any, default: nil
  prop is_remote, :boolean, default: false
  prop parent_id, :any, default: nil
  prop published_in, :any, default: nil

  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false

  slot extra_items, required: false
  slot admin_items, required: false

  def render(assigns) do
    creator = creator_or_subject(assigns.activity, assigns.object)

    assigns
    |> assign(
      creator: creator,
      creator_id: creator_or_subject_id(assigns.activity, assigns.object, creator),
      name: name(assigns.activity, assigns.object, creator)
    )
    |> render_sface()
  end

  def creator_or_subject(activity, object) do
    e(object, :created, :creator, nil) || e(activity, :subject, nil)
  end

  def creator_or_subject_id(activity, object, subject \\ nil) do
    id(subject) || e(object, :created, :creator_id, nil) || e(object, :creator_id, nil) ||
      e(activity, :subject_id, nil)
  end

  def name(activity, object, subject \\ nil) do
    e(subject || creator_or_subject(activity, object), :profile, :name, l("this user"))
  end
end
