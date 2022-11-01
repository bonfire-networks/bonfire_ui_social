defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text

  prop object, :any
  prop activity, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop thread_mode, :any, default: nil
  prop permalink, :string, default: nil
  prop date_ago, :string, default: nil
  prop showing_within, :string, default: nil
  prop activity_inception, :any, default: nil

  def preloads(),
    do: [
      :post_content
    ]

  def post_content(object) do
    e(object, :post_content, object)
    # |> debug("activity_note_object")
  end

  def maybe_truncate(input, activity_inception, length \\ 250) do
    if activity_inception,
      do: Text.sentence_truncate(input, length, "..."),
      else: input
  end
end
