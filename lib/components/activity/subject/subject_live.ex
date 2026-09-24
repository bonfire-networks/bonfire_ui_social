defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any, default: []
  prop profile_name, :string, default: nil
  prop profile_summary, :string, default: nil
  prop profile_media, :string, default: nil

  prop character, :any, default: nil
  prop character_username, :string, default: nil

  prop verb, :string, default: nil
  prop experienced_as, :atom, default: nil

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
  prop published_in_placement, :atom, default: :hidden
  prop published_in_path, :any, default: nil
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

  @doc """
  The name a subject line shows, for the email templates, which render without the page's later loading. See `email_username/1`.
  """
  def email_name(assigns),
    do: e(assigns, :profile, :name, nil) || e(email_person(assigns), :profile, :name, nil)

  @doc "The username a subject line shows, for the email templates."
  def email_username(assigns),
    do:
      e(assigns, :character, :username, nil) ||
        e(email_person(assigns), :character, :username, nil)

  @doc "Whether a subject line would only name the reader (the author of their own post under a like of it), which an email leaves out as it says nothing."
  def email_about_reader?(assigns),
    do:
      not is_nil(assigns[:subject_id]) and
        assigns[:subject_id] == current_user_id(assigns[:__context__])

  # the line is about `subject_id`, which is not always whoever did the activity: under a like it is the liked post's author. So the person is whichever loaded one has that id, and the reader counts, since the feed does not load a reader's own profile again (it is the current user)
  defp email_person(assigns) do
    subject_id = assigns[:subject_id]

    Enum.find(
      [
        e(assigns, :activity, :subject, nil),
        e(assigns, :object, :created, :creator, nil),
        current_user(assigns[:__context__])
      ],
      &(is_nil(subject_id) or id(&1) == subject_id)
    )
  end
end
