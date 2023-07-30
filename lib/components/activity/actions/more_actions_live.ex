defmodule Bonfire.UI.Social.Activity.MoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Social.Integration
  # alias Bonfire.UI.Common.OpenModalLive
  # alias Bonfire.UI.Social.Integration

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

  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false

  slot extra_items, required: false
  slot admin_items, required: false

  def render(assigns) do
    subject = subject(assigns.activity, assigns.object)

    assigns
    |> assign(
      subject: subject,
      subject_id: subject_id(assigns.activity, assigns.object, subject),
      name: name(assigns.activity, assigns.object, subject)
    )
    |> render_sface()
  end

  def subject(activity, object) do
    e(activity, :subject, nil) || e(object, :created, :creator, nil)
  end

  def subject_id(activity, object, subject \\ nil) do
    id(subject || subject(activity, object)) || e(activity, :subject_id, nil) ||
      e(object, :created, :creator_id, nil) || e(object, :creator_id, nil)
  end

  def name(activity, object, subject \\ nil) do
    e(subject || subject(activity, object), :profile, :name, l("this user"))
  end
end
