defmodule Bonfire.UI.Social.Activity.EmbedActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity, :any, default: nil
  prop creator, :any, default: nil
  prop object, :any, required: true
  prop object_type, :any, default: nil
  prop object_type_readable, :any, default: nil
  prop object_boundary, :any, default: nil
  prop verb, :string, default: nil
  prop thread_id, :string, default: nil
  prop thread_mode, :any, default: nil
  prop thread_title, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop is_remote, :boolean, default: false
  prop permalink, :string, default: nil
  prop reply_count, :any, default: nil
  prop hide_reply, :boolean, default: false
  prop my_like, :any, default: nil
  prop flagged, :any, default: nil
  prop parent_id, :any, default: nil
  prop id, :string, default: nil
  prop event_target, :any, default: nil

  def render(assigns) do
    creator = assigns[:creator]

    assigns
    |> assign(creator_id: id(creator))
    |> render_sface()
  end
end
