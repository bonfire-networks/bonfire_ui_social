defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any, default: []
  prop profile_name, :string, default: nil
  prop profile_summary, :string, default: nil
  prop profile_media, :string, default: nil

  prop character, :any, default: nil
  prop character_username, :string, default: nil

  prop verb, :string, default: nil
  prop verb_display, :string, default: nil

  prop activity_id, :any, default: nil
  prop subject_id, :any, default: nil
  prop object_id, :any, default: nil
  prop subject_user, :any, default: nil

  prop subject_peered, :any, default: nil
  prop peered, :any, default: nil
  prop is_remote, :boolean, default: false

  prop reply_to_id, :any, default: nil
  prop date_ago, :any, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop published_in, :any, default: nil
  prop feed_id, :any, default: nil
  prop path, :string, default: nil
  prop is_answer, :boolean, default: false
  prop activity_inception, :any, default: nil
  prop parent_id, :any, default: nil
  prop show_minimal_subject_and_note, :any, default: nil
  prop extra_info, :any, default: nil
  prop replies_more_count, :integer, default: 0

  def prepare_path(character_username, subject_id, user) do
    if character_username,
      do: "/@#{character_username}",
      else: "/user/#{subject_id || id(user)}"
  end

  def preloads(),
    do: [
      :post_content
    ]

  def post_content(object) do
    e(object, :post_content, object)
  end
end
