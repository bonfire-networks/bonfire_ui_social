defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text

  prop object, :any
  prop activity, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :string, default: nil
  prop activity_inception, :any, default: nil
  prop cw, :boolean, default: nil

  def preloads(),
    do: [
      :post_content
    ]

  def post_content(object) do
    e(object, :post_content, object)
    # |> debug("activity_note_object")
  end

  def maybe_truncate(input, activity_inception, viewing_main_object, length \\ 250) do
    if viewing_main_object != true and activity_inception != nil and is_binary(input) and
         input != "",
       do: Text.sentence_truncate(input, length, "..."),
       else: input
  end
end
