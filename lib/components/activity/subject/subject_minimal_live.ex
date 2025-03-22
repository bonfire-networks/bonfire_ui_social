defmodule Bonfire.UI.Social.Activity.SubjectMinimalLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop activity_id, :any, default: nil
  prop object_id, :any, default: nil
  prop peered, :any, default: nil
  # prop reply_to_id, :any, default: nil
  # prop profile, :any, default: nil
  # prop character, :any, default: nil
  prop verb, :string, default: nil
  prop verb_display, :string, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil
  prop subject_id, :any, default: nil
  prop subject_user, :any, default: nil
  prop profile_name, :string, default: nil
  prop character_username, :string, default: nil
  prop path, :string, default: nil
  prop profile_media, :string, default: nil
  prop profile_id, :string, default: nil
  prop parent_id, :any, default: nil
  prop emoji, :any, default: nil

  def render(assigns),
    do: Bonfire.UI.Social.Activity.SubjectLive.prepare(assigns) |> render_sface()
end
