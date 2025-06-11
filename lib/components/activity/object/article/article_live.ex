defmodule Bonfire.UI.Social.Activity.ArticleLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.Common.Text
  import Phoenix.LiveView.JS

  prop object, :any
  # prop profile, :any, default: nil
  prop activity, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop cw, :boolean, default: nil
  prop is_remote, :boolean, default: false
  prop thread_title, :any, default: nil
  # prop thread_mode, :atom, default: nil
  prop hide_actions, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop parent_id, :any, default: nil

  def preloads(),
    do: [
      :post_content
    ]

  def post_content(object) do
    e(object, :post_content, nil) || object
    # |> debug("activity_note_object")
  end

  def maybe_truncate(input, skip \\ false, length \\ 800)

  def maybe_truncate(input, skip, length) when skip != true and is_binary(input) do
    Text.sentence_truncate(input, length, "...")
  end

  def maybe_truncate(input, _skip, _length), do: input

  # Helper function for checking expandable content after render
  def check_expandable(id) do
    %JS{}
    |> JS.dispatch("bonfire:check-expandable")
  end
end
