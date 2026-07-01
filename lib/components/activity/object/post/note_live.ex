defmodule Bonfire.UI.Social.Activity.NoteLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity, :any, default: nil
  prop viewing_main_object, :boolean, default: false
  prop showing_within, :atom, default: nil
  prop cw, :boolean, default: nil
  prop is_remote, :boolean, default: false
  prop thread_title, :any, default: nil
  prop hide_actions, :boolean, default: false
  prop activity_inception, :boolean, default: false
  prop activity_component_id, :string, default: nil
  prop parent_id, :any, default: nil

  def preloads(),
    do: [
      :post_content,
      :language
    ]

  def post_content(object) do
    e(object, :post_content, nil) || object
  end
end
