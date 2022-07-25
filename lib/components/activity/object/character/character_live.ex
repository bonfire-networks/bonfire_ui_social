defmodule Bonfire.UI.Social.Activity.CharacterLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop activity, :any
  prop verb_display, :string
  prop permalink, :string
  prop date_ago, :string
  prop showing_within, :any

  def the_other(activity, object, context) do
    current_user = current_user(context)
    if ulid(object) != ulid(current_user) or !e(activity, :subject, :profile, nil) do
      object
    else
      e(activity, :subject, nil)
    end
  end

  def preloads(), do: [
    :character,
    profile: [:icon],
  ]

end
