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

  prop activity_id, :any, default: nil
  prop subject_id, :any, default: nil
  prop object_id, :any, default: nil
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
  prop subject_user, :any, default: nil
  prop path, :string, default: nil
  prop is_answer, :boolean, default: false
  prop activity_inception, :any, default: nil
  prop parent_id, :any, default: nil

  def render(assigns) do
    assigns
    |> prepare()
    |> render_sface()
  end

  @spec prepare(any()) :: any()
  def prepare(
        %{
          profile_name: nil,
          character_username: nil,
          subject_id: current_user_id,
          __context__: %{
            current_user: %{id: current_user_id, profile: profile, character: character}
          }
        } = assigns
      ) do
    assigns
    |> assign(
      subject_id: current_user_id,
      profile_name: e(profile, :name, nil),
      character_username: e(character, :username, nil),
      path: path(character),
      profile_media: Common.Media.avatar_url(profile)
    )
  end

  def prepare(
        %{
          profile_name: nil,
          character_username: nil,
          subject_id: subject_user_id,
          subject_user: %{id: subject_user_id, profile: profile, character: character}
        } = assigns
      ) do
    assigns
    |> assign(
      subject_id: subject_user_id,
      profile_name: e(profile, :name, nil),
      character_username: e(character, :username, nil),
      path: path(character),
      profile_media: Media.avatar_url(profile)
    )
  end

  def prepare(
        %{
          profile: profile,
          character: character
        } = assigns
      )
      when not is_nil(profile) or not is_nil(character) do
    assigns
    |> assign(
      subject_id: id(profile),
      profile_name: e(profile, :name, nil),
      character_username: e(character, :username, nil),
      path: path(character || profile),
      profile_media: Media.avatar_url(profile)
    )
  end

  def prepare(assigns) do
    assigns
    |> debug("could not prepare")
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
