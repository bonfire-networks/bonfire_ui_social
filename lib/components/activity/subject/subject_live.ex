defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text

  prop activity_id, :any, default: nil
  prop object_id, :any, default: nil
  prop peered, :any, default: nil
  prop reply_to_id, :any, default: nil
  prop profile, :any, default: nil
  prop character, :any, default: nil
  prop date_ago, :any, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :atom, default: nil
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop thread_id, :string, default: nil
  prop thread_title, :any, default: nil
  prop cw, :boolean, default: nil
  prop show_minimal_subject_and_note, :any, default: false
  prop published_in, :any, default: nil
  prop subject_id, :any, default: nil
  prop subject_user, :any, default: nil

  def render(assigns) do
    assigns
    |> prepare()
    |> render_sface()
  end

  def prepare(
        %{
          profile: nil,
          character: nil,
          subject_id: id,
          current_user: %{id: id, profile: profile, character: character}
        } = assigns
      ) do
    assigns
    |> assign(
      profile: profile,
      character: character
    )
  end

  def prepare(
        %{
          profile: nil,
          character: nil,
          subject_id: id,
          subject_user: %{id: id, profile: profile, character: character}
        } = assigns
      ) do
    assigns
    |> assign(
      profile: profile,
      character: character
    )
  end

  def prepare(assigns) do
    assigns
    # |> debug("could not prepare")
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
