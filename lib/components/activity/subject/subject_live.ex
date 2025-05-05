defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text
  alias Bonfire.Social.Feeds.LiveHandler

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
  prop path, :string, default: nil
  prop is_answer, :boolean, default: false
  prop activity_inception, :any, default: nil
  prop parent_id, :any, default: nil
  prop show_minimal_subject_and_note, :any, default: nil
  prop extra_info, :any, default: nil

  # def render(assigns) do
  #   assigns
  #   |> debug("assigns received")
  #   |> prepare()
  #   |> debug("assigns prepared")
  #   |> render_sface()
  # end

  def prepare(assigns, caller \\ __MODULE__) do
    subject_id =
      assigns[:subject_id]
      |> debug("subject_id")

    if creator_or_subject = current_subject(assigns[:subject_id], assigns) do
      debug(
        creator_or_subject,
        "profileA for #{assigns[:verb]} / #{subject_id} via #{caller} - creator_or_subject from current_user or subject_user"
      )

      creator_or_subject_id = id(creator_or_subject)

      character_username =
        e(creator_or_subject, :character, :username, nil) || e(assigns, :character_username, nil)

      assigns
      |> assign(
        # Subject/profile details
        subject_id: creator_or_subject_id,
        profile_name:
          e(creator_or_subject, :profile, :name, nil) || e(assigns, :profile_name, nil),
        character_username: character_username,
        path:
          path(creator_or_subject) ||
            prepare_path(character_username, creator_or_subject_id, creator_or_subject),
        profile_media: Common.Media.avatar_url(creator_or_subject)
      )
    else
      character = e(assigns, :character, nil)
      profile = e(assigns, :profile, nil)

      debug(profile || character, "profileB for #{assigns[:verb]} via #{caller} / #{subject_id}")

      subject_id = subject_id || id(profile) || id(character)

      character_username = e(character, :username, nil) || e(assigns, :character_username, nil)

      assigns
      |> assign(
        subject_id: subject_id,
        profile_name: e(profile, :name, nil) || e(assigns, :profile_name, nil),
        character_username: character_username,
        path:
          if(character, do: path(character)) ||
            prepare_path(character_username, subject_id, character || profile),
        profile_media: Media.avatar_url(profile)
      )
    end
  end

  def current_creator_or_subject(assigns) do
    activity = assigns[:activity]
    object = assigns[:object] || e(activity, :object, nil)

    creator_or_subject =
      (e(object, :created, :creator, nil) || e(activity, :created, :creator, nil) ||
         e(object, :creator, nil) || e(activity, :subject, nil))
      |> debug("creator_or_subject")

    creator_or_subject_id =
      (id(creator_or_subject) || e(object, :created, :creator_id, nil) ||
         e(activity, :created, :creator_id, nil) || e(object, :creator_id, nil) ||
         e(activity, :subject_id, nil))
      |> debug("creator_or_subject_id")

    current_subject(creator_or_subject || creator_or_subject_id, assigns)
  end

  def current_subject(creator_or_subject, %{} = assigns) do
    current_user =
      current_user(assigns)
      |> debug("current_user")

    subject_user =
      assigns[:subject_user]
      |> debug("subject_user")

    current_subject(creator_or_subject, subject_user, current_user)
  end

  def current_subject(creator_or_subject, subject_user, current_user) do
    creator_or_subject_id = id(creator_or_subject)

    # Determine which user data to use based on matching IDs
    cond do
      current_user && creator_or_subject_id == id(current_user) ->
        current_user

      subject_user && creator_or_subject_id == id(subject_user) ->
        subject_user

      true ->
        if is_map(creator_or_subject), do: creator_or_subject
    end
  end

  # @spec prepare(any()) :: any()
  # def prepare(
  #       %{
  #         profile_name: profile_name,
  #         character_username: character_username,
  #         subject_id: subject_id,
  #         __context__: %{
  #           current_user: %{id: current_user_id, profile: profile, character: character}
  #         }
  #       } = assigns
  #     )
  #     when subject_id == current_user_id and (is_nil(profile_name) or is_nil(character_username)) do
  #   character_username = e(character, :username, character_username)

  #   assigns
  #   |> assign(
  #     subject_id: current_user_id,
  #     profile_name: e(profile, :name, profile_name),
  #     character_username: character_username,
  #     path: path(character) || prepare_path(character_username, subject_id, character, profile),
  #     profile_media: Common.Media.avatar_url(profile)
  #   )
  # end

  # def prepare(
  #       %{
  #         profile_name: profile_name,
  #         character_username: character_username,
  #         subject_id: subject_id,
  #         subject_user: %{id: subject_user_id, profile: profile, character: character}
  #       } = assigns
  #     )
  #     when subject_id == subject_user_id and (is_nil(profile_name) or is_nil(character_username)) do
  #   character_username = e(character, :username, character_username)

  #   assigns
  #   |> assign(
  #     subject_id: subject_user_id,
  #     profile_name: e(profile, :name, profile_name),
  #     character_username: character_username,
  #     path: path(character) || prepare_path(character_username, subject_id, character, profile),
  #     profile_media: Media.avatar_url(profile)
  #   )
  # end

  # def prepare(
  #       %{
  #         profile: profile,
  #         character: character
  #       } = assigns
  #     )
  #     when not is_nil(profile) or not is_nil(character) do
  #   subject_id = id(profile || character)
  #   character_username = e(character, :username, nil) || e(assigns, :character_username, nil)

  #   assigns
  #   |> assign(
  #     subject_id: subject_id,
  #     profile_name: e(profile, :name, nil) || e(assigns, :profile_name, nil),
  #     character_username: character_username,
  #     path: path(character) || prepare_path(character_username, subject_id, character, profile),
  #     profile_media: Media.avatar_url(profile)
  #   )
  # end

  # def prepare(assigns) do
  #   assigns
  #   |> debug("could not prepare")
  # end

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
    # |> debug("activity_note_object")
  end

  def maybe_truncate(input, viewing_main_object, length \\ 250) do
    if viewing_main_object != true and is_binary(input) and
         input != "",
       do: input |> String.replace("\n", " ") |> Text.sentence_truncate(length, "..."),
       else: input
  end
end
