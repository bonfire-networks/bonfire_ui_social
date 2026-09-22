defmodule Bonfire.UI.Social.Activity.SubjectListModalLive do
  @moduledoc """
  Modal listing all the users (subjects) involved in a grouped activity
  such as "X, Y and N others liked/reacted/boosted".
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true

  # what the activity was for whoever is reading, since the title turns on a distinction the stored verb cannot make: a reaction and a plain like are both stored as likes
  prop experienced_as, :atom, default: nil
  prop main_profile_id, :any, default: nil
  prop main_profile_name, :string, default: nil
  prop main_character_username, :string, default: nil
  prop main_profile_media, :any, default: nil
  prop main_is_remote, :boolean, default: true
  prop subjects_more, :list, default: []
  prop trigger_text, :string, required: true
  prop trigger_class, :css_class, default: "link link-hover font-bold"
  prop parent_id, :any, default: nil

  @doc """
  The heading over the list: the word for what they all did, from what the activity was.

  Composed rather than declared, so a kind nobody thought about still reads correctly, and there is no second place to name a like.
  """
  def title_for(experience) do
    experience
    |> Bonfire.Social.Activities.experience_display()
    |> String.capitalize()
  end
end
