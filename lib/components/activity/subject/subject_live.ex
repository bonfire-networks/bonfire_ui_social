defmodule Bonfire.UI.Social.Activity.SubjectLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text
  # alias Bonfire.UI.Social.ActivityLive

  prop activity, :map, default: nil
  prop object, :any, default: nil
  prop profile, :any, default: nil
  prop character, :any, default: nil
  prop date_ago, :any, default: nil
  prop permalink, :string, default: nil
  prop showing_within, :any, default: :feed
  prop object_type, :any, default: nil
  prop object_boundary, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop thread_id, :string, default: nil
  prop cw, :boolean, default: nil
  prop show_minimal_subject_and_note, :boolean, default: false

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
