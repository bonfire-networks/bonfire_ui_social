defmodule Bonfire.UI.Social.Activity.CharacterLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity, :any
  prop verb_display, :string
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any

  def the_other(assigns) do
    me = current_user(assigns)
    if e(assigns, :object, :id, nil) != e(me, :id, nil) or is_nil e(assigns, :activity, :subject, nil) do
      e(assigns, :object, nil)
    else
      e(assigns, :activity, :subject, nil)
    end
  end

  def preloads(), do: [
    :character,
    profile: [:icon],
  ]

end
